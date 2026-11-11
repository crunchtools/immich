#!/bin/bash
# Immich image contract: boot the image under systemd and prove the whole stack
# comes up, not just PID 1. Run with IMAGE set (the release workflow does).
#
# Proves: PostgreSQL, Valkey, the db-init oneshot and the Immich server all
# start; the Immich server answers /api/server/ping on 2283 (it has already
# connected to PostgreSQL and Valkey and run its migrations to get there); the
# pgvector, cube, earthdistance, pg_trgm and unaccent extensions exist.
# Does not prove: uploads, thumbnails or transcoding (no media in CI), or
# machine learning (disabled in /etc/immich.env), or a mounted /srv volume.
set -euo pipefail

: "${IMAGE:?set IMAGE to the image to test}"
timeout="${CONTRACT_TIMEOUT:-300}"
name="immich-contract-$$"

cleanup() { podman rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

podman run -d --name "$name" --systemd=always "$IMAGE" >/dev/null

fail() {
  echo "contract FAILED: $*" >&2
  podman exec "$name" systemctl --failed --no-legend >&2 || true
  podman exec "$name" journalctl -u immich-server -n 60 --no-pager >&2 || true
  exit 1
}

deadline=$((SECONDS + timeout))
until podman exec "$name" curl -fsS http://127.0.0.1:2283/api/server/ping 2>/dev/null | grep -q pong; do
  [ "$SECONDS" -lt "$deadline" ] || fail "no pong from /api/server/ping within ${timeout}s"
  sleep 3
done
echo "ok: immich-server answered /api/server/ping"

for unit in postgresql valkey immich-db-init immich-server; do
  [ "$(podman exec "$name" systemctl is-active "$unit")" = active ] || fail "$unit is not active"
done
echo "ok: postgresql valkey immich-db-init immich-server active"

exts=$(podman exec "$name" runuser -u postgres -- psql -d immich -tAc "SELECT extname FROM pg_extension")
for ext in vector cube earthdistance pg_trgm unaccent; do
  grep -qx "$ext" <<<"$exts" || fail "extension $ext missing"
done
echo "ok: database extensions present"
