# minecraft-railway

Railway wrapper image for a Paper Minecraft server, built on
[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server) pinned by digest.

Upstream image: `itzg/minecraft-server:2026.8.2-java25`
(`sha256:efa878ddb49cf5251b2e5f2ad71b08fd2f7236c1f7907433f6697258b31d2ce4`).
Minecraft `26.2`, server type `PAPER`.

## What this adds

1. **The JVM heap is sized from the container's own cgroup limit.** A container reports the
   host's total memory, so a fixed `MAX_MEMORY` is either an out-of-memory kill or wasted
   plan. `railway-entrypoint.sh` reads `/sys/fs/cgroup/memory.max`, reserves 25% (clamped to
   512-2048 MB) for the JVM's non-heap footprint and the operating system, and exports the
   remainder as `MAX_MEMORY`. Setting `MAX_MEMORY`, `MEMORY` or `JVM_XX_OPTS` yourself turns
   the sizing off.
2. **Rotating world backups, taken consistently.** `railway-backup.sh` runs `save-off`,
   `save-all flush`, archives every `world*` directory to `/data/backups`, then `save-on`,
   over RCON. `BACKUP_INTERVAL_HOURS` (default 6, `0` disables) and `BACKUP_KEEP` (default 5)
   control it.
3. **The container refuses to boot without an RCON password**, rather than starting with a
   blank or a well-known one.

## Environment

Baked into the image, so the deploy form stays empty: `EULA`, `TYPE`, `VERSION`,
`ONLINE_MODE`, `USE_AIKAR_FLAGS`, `ENABLE_RCON`, `RCON_PORT`, `SERVER_PORT`,
`ENABLE_ROLLING_LOGS`, `MAX_TICK_TIME`, `JVM_DD_OPTS`, `EXISTING_OPS_FILE`.

Set by the deployer: `RCON_PASSWORD` (required), and any
[upstream variable](https://docker-minecraft-server.readthedocs.io/) such as `DIFFICULTY`,
`MAX_PLAYERS`, `MOTD`, `OPS`, `SEED`, `LEVEL_TYPE`, `WHITELIST`.

## Volume

Mount at `/data`. Worlds, plugins, configuration and `/data/backups` live there.
