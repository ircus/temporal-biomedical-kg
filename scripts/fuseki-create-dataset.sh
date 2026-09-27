#!/usr/bin/env bash
# Create the project's TDB2 dataset in Fuseki if it doesn't already exist.
#
# Usage: scripts/fuseki-create-dataset.sh
# Env vars (all optional, matching docker-compose.yml defaults):
#   FUSEKI_PORT (3031), FUSEKI_ADMIN_PASSWORD (changeme), FUSEKI_DATASET (kg)
set -euo pipefail

port="${FUSEKI_PORT:-3031}"
password="${FUSEKI_ADMIN_PASSWORD:-changeme}"
dataset="${FUSEKI_DATASET:-kg}"
base="http://localhost:${port}"

existing=$(curl -s -o /dev/null -w '%{http_code}' -u "admin:${password}" "${base}/${dataset}")
if [ "$existing" = "200" ]; then
  echo "Dataset '${dataset}' already exists at ${base}/${dataset}"
  exit 0
fi

curl -sf -u "admin:${password}" -X POST \
  --data "dbName=${dataset}&dbType=tdb2" \
  "${base}/$/datasets"
echo "Created dataset '${dataset}' at ${base}/${dataset}"
