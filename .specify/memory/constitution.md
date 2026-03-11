# immich Constitution

> **Version:** 1.0.0
> **Ratified:** 2026-03-10
> **Status:** Active
> **Inherits:** [crunchtools/constitution](https://github.com/crunchtools/constitution) v1.3.0
> **Profile:** Web Application

Immich photo management — all-in-one container on ubi10-core. Packages the upstream Immich application with PostgreSQL, Valkey (Redis-compatible), and ffmpeg into a single systemd-managed container using RHEL packages where possible.

---

## License

AGPL-3.0-or-later

## Versioning

Follow Semantic Versioning 2.0.0. MAJOR/MINOR/PATCH. Version tracks the upstream Immich release bundled in the image.

## Base Image

`quay.io/crunchtools/ubi10-core:latest` — inherits systemd hardening and troubleshooting tools from the crunchtools image tree.

**Parent image for cascade rebuild:** `quay.io/crunchtools/ubi10-core`

## Application Runtime

- **Language:** Node.js (Immich server is a NestJS application)
- **Database:** PostgreSQL with pgvector 0.7.4 extension (built from source)
- **Cache:** Valkey (Redis-compatible, from EPEL)
- **Media processing:** ffmpeg (from RPMFusion), libvips (built from source)
- **Dependencies built from source:** libvips 8.15.2 (not in UBI repos), pgvector 0.7.4 (EPEL has 0.6.2)
- **Services:**
  - `postgresql.service` — PostgreSQL database with pgvector, cube, earthdistance extensions
  - `valkey.service` — Valkey cache (localhost only)
  - `immich-db-init.service` — Database initialization (Type=oneshot, After=postgresql, Before=immich-server)
  - `immich-server.service` — Immich Node.js server on port 2283
- **Entry point:** `/sbin/init` (systemd)

## Host Directory Convention

Host data lives under `/srv/immich/`:

- `config/` — environment file (`/etc/immich.env`) bind-mounted `:ro,Z`
- `data/` — PostgreSQL data (`/var/lib/pgsql/data`), photo uploads (`/usr/src/app/upload`) bind-mounted `:Z`

## Data Persistence

PostgreSQL stores all metadata. Photo and video uploads persist in `/usr/src/app/upload`. Database initialization uses a oneshot systemd service:

```
immich-db-init.service (Type=oneshot)
  After=postgresql.service
  Before=immich-server.service
```

The init service creates the immich database and user, then enables required PostgreSQL extensions (vector, cube, earthdistance, pg_trgm, unaccent). VOLUME declarations for `/var/lib/pgsql/data` and `/usr/src/app/upload`.

## Containerfile Conventions

- **Multi-stage build**: Three builder stages (immich-source, vips-build, pgvector-build) compile dependencies; final stage copies artifacts onto ubi10-core
- `rootfs/` directory provides systemd units, init script, and environment file
- **Single RUN layer for RHSM**: register, install postgresql-server and all runtime packages, unregister — all in one layer to avoid credential leakage
- EPEL and RPMFusion repos added for Valkey and ffmpeg
- Required LABELs: `maintainer`, `description`
- `dnf clean all` after package installation

## Runtime Configuration

- Environment file: `/etc/immich.env` loaded via systemd `EnvironmentFile=`
- Database credentials via environment variables (`DB_HOSTNAME`, `DB_USERNAME`, `DB_PASSWORD`)
- Machine learning disabled by default (`IMMICH_MACHINE_LEARNING_ENABLED=false`)
- Valkey bound to localhost only for security
- No hardcoded credentials — all configurable via environment

## Registry

Published to `quay.io/crunchtools/immich`.

## Cascade Rebuild

Workflow includes `repository_dispatch` listener for `parent-image-updated` events. When `ubi10-core` is updated, immich rebuilds automatically. RHSM secrets passed via build secret mounts.

## Monitoring

Zabbix monitoring:
- Web scenario (HTTP check) for Immich server on port 2283
- TCP port check for PostgreSQL on port 5432
- TCP port check for Valkey on port 6379
- `pg_isready` health check for database connectivity

## Testing

- **Build test**: CI builds the multi-stage Containerfile on every push to main
- **Health check**: Immich server responds on port 2283
- **Database connectivity**: PostgreSQL accepts connections with pgvector extension loaded
- **Smoke test**: Immich API responds to health endpoint

## Quality Gates

1. Build — Multi-stage Containerfile builds successfully
2. Application health test — Immich server responds on port 2283
3. Push — Image pushed to Quay.io
