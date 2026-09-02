#!/bin/bash
# Railway entrypoint for the Paper Minecraft server.
#
# Runs before upstream's own start script and does three things:
#   * refuses to boot without an RCON password (the backup job and the console both need it),
#   * sizes the JVM heap from this container's cgroup limit unless the deployer set it, and
#   * starts the rotating world-backup loop in the background.
# Then it hands over to upstream's entrypoint unchanged.
set -euo pipefail

log() { echo "[railway] $*"; }

if [ -z "${RCON_PASSWORD:-}" ]; then
  log "FATAL: RCON_PASSWORD is empty. Set it to a long random string and redeploy."
  log "       Without it the server would accept remote console commands from anyone"
  log "       who can reach the container, and world backups cannot be taken."
  exit 1
fi

# ---------------------------------------------------------------- heap sizing
# A container reports the HOST's memory in /proc/meminfo, so the JVM's own
# ergonomics are wrong here; the cgroup limit is the number that matters.
cgroup_limit_bytes() {
  local v
  if [ -r /sys/fs/cgroup/memory.max ]; then
    v=$(cat /sys/fs/cgroup/memory.max)
  elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    v=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
  else
    v=max
  fi
  case "$v" in
    max|''|*[!0-9]*) echo 0 ;;
    # An "unlimited" cgroup reports a number larger than any real machine.
    *) if [ "$v" -gt 1099511627776 ]; then echo 0; else echo "$v"; fi ;;
  esac
}

if [ -n "${MAX_MEMORY:-}" ] || [ -n "${MEMORY:-}" ] || [ -n "${JVM_XX_OPTS:-}" ]; then
  log "heap: left alone, the deploy sets its own memory options"
else
  limit_bytes=$(cgroup_limit_bytes)
  if [ "$limit_bytes" -eq 0 ]; then
    limit_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    log "heap: no cgroup memory limit found, falling back to MemTotal ${limit_mb}M"
  else
    limit_mb=$((limit_bytes / 1024 / 1024))
  fi

  # Reserve room for everything the JVM holds outside the heap: metaspace, code
  # cache, GC structures, thread stacks and Netty's direct buffers. Measured at
  # ~420 MB on an idle empty Paper world, and it grows with players and plugins.
  reserve_mb=$((limit_mb * MEMORY_RESERVE_FRACTION / 100))
  [ "$reserve_mb" -lt "$MEMORY_RESERVE_MIN_MB" ] && reserve_mb=$MEMORY_RESERVE_MIN_MB
  [ "$reserve_mb" -gt "$MEMORY_RESERVE_MAX_MB" ] && reserve_mb=$MEMORY_RESERVE_MAX_MB

  heap_mb=$((limit_mb - reserve_mb))
  # On a very small container the flat reserve would eat the whole allowance.
  if [ "$heap_mb" -lt $((limit_mb * 60 / 100)) ]; then
    heap_mb=$((limit_mb * 60 / 100))
  fi
  [ "$heap_mb" -lt 400 ] && heap_mb=400

  export MAX_MEMORY="${heap_mb}M"
  log "heap: container limit ${limit_mb}M, reserving ${reserve_mb}M for non-heap, MAX_MEMORY=${MAX_MEMORY}"
fi

# ---------------------------------------------------------------- backups
if [ "${BACKUP_INTERVAL_HOURS:-0}" != "0" ]; then
  log "backups: every ${BACKUP_INTERVAL_SECONDS:-$(( ${BACKUP_INTERVAL_HOURS} * 3600 ))}s, keeping ${BACKUP_KEEP}, in /data/backups"
  /railway/backup.sh &
else
  log "backups: disabled (BACKUP_INTERVAL_HOURS=0)"
fi

exec /image/scripts/start "$@"
