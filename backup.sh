#!/bin/bash
set -eo pipefail

echo "[backup] starting"

if [ -z "$GCS_SERVICE_ACCOUNT_JSON" ]; then echo "[backup] ERROR: missing GCS_SERVICE_ACCOUNT_JSON" >&2; exit 1; fi
if [ -z "$GCS_BUCKET" ]; then echo "[backup] ERROR: missing GCS_BUCKET" >&2; exit 1; fi

if [ -z "$PGHOST" ] || [ -z "$PGPORT" ] || [ -z "$PGDATABASE" ] || [ -z "$PGUSER" ] || [ -z "$PGPASSWORD" ]; then
  echo "[backup] ERROR: missing one of PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD" >&2
  exit 1
fi

GOOGLE_APPLICATION_CREDENTIALS_DIR="/gcp"
GOOGLE_APPLICATION_CREDENTIALS_FILE="$GOOGLE_APPLICATION_CREDENTIALS_DIR/gcs-sa.json"

# Write Google Cloud Storage service account key JSON to a file
echo "[backup] GCS service account JSON found, writing credentials to $GOOGLE_APPLICATION_CREDENTIALS_FILE..."
mkdir -p "$GOOGLE_APPLICATION_CREDENTIALS_DIR"
echo "[backup] Created directory $GOOGLE_APPLICATION_CREDENTIALS_DIR"
echo "$GCS_SERVICE_ACCOUNT_JSON" > "$GOOGLE_APPLICATION_CREDENTIALS_FILE"
echo "[backup] Credentials written successfully"
chmod 600 "$GOOGLE_APPLICATION_CREDENTIALS_FILE"

export GOOGLE_APPLICATION_CREDENTIALS="$GOOGLE_APPLICATION_CREDENTIALS_FILE"

if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "[backup] ERROR: GOOGLE_APPLICATION_CREDENTIALS is not set (example: /gcp/gcs-sa.json)" >&2
  exit 1
fi

if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "[backup] ERROR: Credentials file does not exist at $GOOGLE_APPLICATION_CREDENTIALS" >&2
  exit 1
fi

echo "[backup] Activating GCS service account..."
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"

if [[ ! "$GCS_BUCKET" =~ ^gs:// ]]; then
  echo "[backup] ERROR: GCS_BUCKET must start with gs:// (got: $GCS_BUCKET)" >&2
  exit 1
fi

TS=$(date -u +"%Y%m%dT%H%M%SZ")
DEST="${GCS_BUCKET}/basebackups/${PGDATABASE}/${TS}.tar.gz"

echo "[backup] creating base backup -> ${DEST}"
echo "[backup] connecting to ${PGHOST}:${PGPORT} db=${PGDATABASE} user=${PGUSER}"

# Stream a compressed tar-format base backup to GCS
pg_basebackup \
  -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" \
  -d "$PGDATABASE" \
  -Ft -z -X none \
  -D - \
| gcloud storage cp - "${DEST}"

echo "[backup] done"