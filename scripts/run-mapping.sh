#!/usr/bin/env bash
# Run a SPARQL Anything mapping and write RDF 1.2 Turtle output.
#
# Usage: scripts/run-mapping.sh <mapping-file> <output-file>
# Example: scripts/run-mapping.sh mappings/clinical_events.sparql output/clinical_events.ttl
#
# Must be run from the repo root: SERVICE <x-sparql-anything:location=...>
# paths in mapping files are resolved relative to the current directory.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <mapping-file> <output-file>" >&2
  exit 1
fi

mapping="$1"
output="$2"

mkdir -p "$(dirname "$output")"
sparql-anything -q "$mapping" -f TTL -o "$output"
echo "Wrote $output"
