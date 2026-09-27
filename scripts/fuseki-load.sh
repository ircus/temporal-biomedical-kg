#!/usr/bin/env bash
# Load an RDF file into the project's Fuseki dataset (default graph).
#
# Usage: scripts/fuseki-load.sh <rdf-file>
# Env vars (all optional, matching docker-compose.yml defaults):
#   FUSEKI_PORT (3031), FUSEKI_ADMIN_PASSWORD (changeme), FUSEKI_DATASET (kg)
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <rdf-file>" >&2
  exit 1
fi

file="$1"
port="${FUSEKI_PORT:-3031}"
password="${FUSEKI_ADMIN_PASSWORD:-changeme}"
dataset="${FUSEKI_DATASET:-kg}"
base="http://localhost:${port}"

case "$file" in
  *.ttl) content_type="text/turtle" ;;
  *.nt) content_type="application/n-triples" ;;
  *.nq) content_type="application/n-quads" ;;
  *.trig) content_type="application/trig" ;;
  *) echo "Unsupported extension for $file (expected .ttl/.nt/.nq/.trig)" >&2; exit 1 ;;
esac

curl -sf -u "admin:${password}" -X POST \
  -H "Content-Type: ${content_type}" \
  --data-binary "@${file}" \
  "${base}/${dataset}/data"
echo "Loaded ${file} into ${base}/${dataset}"
