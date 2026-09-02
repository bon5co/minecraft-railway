#!/bin/bash
# Rotating, consistent world backups.
#
# Consistency matters more than the schedule: a tar of a live world directory can
# catch a region file mid-write, so the world is flushed and writes are suspended
# through RCON for the duration of the copy, then resumed.
set -uo pipefail

BACKUP_DIR=/data/backups
INTERVAL_SECONDS=${BACKUP_INTERVAL_SECONDS:-$(( ${BACKUP_INTERVAL_HOURS:-6} * 3600 ))}
KEEP=${BACKUP_KEEP:-5}

log() { echo "[railway-backup] $*"; }

rcon() { rcon-cli --port "${RCON_PORT:-25575}" --password "$RCON_PASSWORD" "$@" >/dev/null 2>&1; }

# Wait for the server to accept RCON before the first backup, then keep the
# interval from the moment the server was actually up.
until rcon list; do sleep 15; done
log "server is up, first backup in ${INTERVAL_SECONDS}s"

while true; do
  sleep "$INTERVAL_SECONDS"

  mkdir -p "$BACKUP_DIR"
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  target="$BACKUP_DIR/world-$stamp.tar.gz"

  worlds=()
  for d in /data/world*; do
    [ -d "$d" ] && worlds+=("$(basename "$d")")
  done
  if [ ${#worlds[@]} -eq 0 ]; then
    log "no world directories yet, skipping"
    continue
  fi

  if ! rcon save-off; then
    log "RCON unreachable, skipping this backup"
    continue
  fi
  rcon save-all flush
  sleep 5

  if tar -czf "$target" -C /data "${worlds[@]}" 2>/dev/null; then
    log "wrote $target ($(du -h "$target" | cut -f1))"
  else
    log "backup FAILED, removing partial file"
    rm -f "$target"
  fi

  rcon save-on

  # Keep the newest $KEEP archives and delete the rest.
  ls -1t "$BACKUP_DIR"/world-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    log "pruning $old"
    rm -f "$old"
  done
done
