# immich Constitution

> **Version:** 1.1.0
> **Ratified:** 2026-03-10
> **Amended:** 2026-10-02
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.22.0
> **Profile:** Web Application

Immich photo management as an all-in-one container: the upstream Immich
server with PostgreSQL, Valkey and ffmpeg in one systemd-managed container,
using RHEL packages where possible.

This file holds what is specific to immich. The fleet rules and the Web
Application profile apply at the inherited version and are checked against
this repo's files by `constitution.yml`. They are not restated here.

## Image and Parent

- **Base:** `quay.io/crunchtools/ubi10-core`, which is also the **parent image
  for cascade**; the build listens for `parent-image-updated`.
- **Published as:** `quay.io/crunchtools/immich`.
- **Versioning:** the image version tracks the upstream Immich release it
  bundles.
- **Multi-stage build:** `immich-source` (the upstream
  `ghcr.io/immich-app/immich-server:release` image), `vips-build` and
  `pgvector-build` feed a final `ubi10-core` stage.
- **Built from source, and why:** libvips 8.15.2 (not in the UBI repos) and
  pgvector 0.7.4 (EPEL ships 0.6.2). Their `-devel` dependencies need RHSM, so
  each RHSM-using stage registers, installs and unregisters in a single `RUN`
  layer with build-secret mounts, so no credential lands in a layer.
- **Extra repos:** EPEL for Valkey and RPMFusion for ffmpeg with full codecs.

## Services

Entry point `/sbin/init` (systemd); units and the init script come from
`rootfs/`.

- `postgresql.service`: PostgreSQL with the pgvector, cube and earthdistance
  extensions.
- `valkey.service`: Redis-compatible cache, bound to `127.0.0.1`.
- `immich-db-init.service`: Type=oneshot, After=postgresql, Before=
  immich-server. Creates the immich database and user and enables vector,
  cube, earthdistance, pg_trgm and unaccent.
- `immich-server.service`: the NestJS Immich server on port 2283.

Machine learning is off by default (`IMMICH_MACHINE_LEARNING_ENABLED=false`).

## Host Layout and Storage

Under `/srv/immich/`:

- `config/`: the environment file, mounted as `/etc/immich.env` `:ro,Z` and
  loaded with systemd `EnvironmentFile=`. Database credentials come from
  `DB_HOSTNAME`, `DB_USERNAME` and `DB_PASSWORD`.
- `data/`: PostgreSQL data (`/var/lib/pgsql/data`) and photo/video uploads
  (`/usr/src/app/upload`), bind-mounted `:Z`. Both paths are declared
  `VOLUME`s. PostgreSQL holds all metadata.

## Monitoring Coverage

Nagios: HTTP check of the Immich server on 2283, TCP checks of PostgreSQL on 5432
and Valkey on 6379, and `pg_isready`.

## Smoke Tests

The server answers its health endpoint on 2283, and PostgreSQL accepts
connections with the pgvector extension loaded.

## History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-10 | Initial constitution |
| 1.1.0 | 2026-10-02 | Manifest under constitution v1.18.0: fleet and profile restatement removed, immich specifics kept; monitoring renamed from Zabbix to Nagios (RT #1478) |
