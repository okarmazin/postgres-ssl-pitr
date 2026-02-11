#!/bin/bash
set -e

echo "[init-walg] Starting WAL-G/Postgres PITR init (runs only on first initdb)"

# Basic checks (keep them simple and explicit)
if ! command -v psql >/dev/null 2>&1; then
  echo "[init-walg] ERROR: psql not found in image" >&2
  exit 1
fi

if ! command -v wal-g >/dev/null 2>&1; then
  echo "[init-walg] ERROR: wal-g not found in image (install it in the Dockerfile)" >&2
  exit 1
fi

if [ -z "$WALG_GS_PREFIX" ]; then
  echo "[init-walg] ERROR: WALG_GS_PREFIX is not set (example: gs://my-bucket/mydb)" >&2
  exit 1
fi

if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "[init-walg] ERROR: GOOGLE_APPLICATION_CREDENTIALS is not set (example: /gcp/gcs-sa.json)" >&2
  exit 1
fi

if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "[init-walg] ERROR: Credentials file does not exist at $GOOGLE_APPLICATION_CREDENTIALS" >&2
  exit 1
fi

echo "[init-walg] WALG_GS_PREFIX=$WALG_GS_PREFIX"
echo "[init-walg] GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS"
echo "[init-walg] wal-g version:"
wal-g --version || true

echo "[init-walg] Applying Postgres WAL archiving settings via ALTER SYSTEM..."

# ---- Apply settings (persisted in postgresql.auto.conf) ----
# During initdb, the official entrypoint runs these scripts with DB available locally.
# We connect over the local socket using the bootstrap superuser.
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'wal-g wal-push %p';
ALTER SYSTEM SET archive_timeout = '60s';
SQL

echo "[init-walg] Done (settings written to postgresql.auto.conf)"