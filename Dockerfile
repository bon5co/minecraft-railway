# Railway-ready Paper Minecraft server.
#
# Wraps the upstream itzg/minecraft-server image, pinned by digest, and adds the two
# things a Railway deploy needs and the image cannot know by itself:
#
#   1. a JVM heap sized from the container's own cgroup limit, instead of a literal
#      that is wrong on every plan but one, and
#   2. consistent, rotating world backups taken through RCON.
FROM itzg/minecraft-server@sha256:efa878ddb49cf5251b2e5f2ad71b08fd2f7236c1f7907433f6697258b31d2ce4

# Everything below is a literal, so it is baked here rather than published as a template
# variable: Railway drops a literal defaultValue at generate time and the variable would
# publish as a blank required field on the deploy form.
ENV EULA=TRUE \
    TYPE=PAPER \
    VERSION=26.2 \
    ONLINE_MODE=TRUE \
    USE_AIKAR_FLAGS=true \
    ENABLE_RCON=true \
    RCON_PORT=25575 \
    SERVER_PORT=25565 \
    ENABLE_ROLLING_LOGS=true \
    MAX_TICK_TIME=-1 \
    JVM_DD_OPTS=disable.watchdog:true \
    EXISTING_OPS_FILE=SYNCHRONIZE \
    BACKUP_INTERVAL_HOURS=6 \
    BACKUP_KEEP=5 \
    MEMORY_RESERVE_FRACTION=25 \
    MEMORY_RESERVE_MIN_MB=512 \
    MEMORY_RESERVE_MAX_MB=2048

COPY railway-entrypoint.sh /railway/entrypoint.sh
COPY railway-backup.sh /railway/backup.sh
RUN chmod +x /railway/entrypoint.sh /railway/backup.sh

EXPOSE 25565
ENTRYPOINT ["/railway/entrypoint.sh"]
