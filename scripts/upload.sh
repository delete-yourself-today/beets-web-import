#!/usr/bin/env bash

set -euo pipefail

jobId="$1"

dir="${TMPDIR:-/tmp}/beet-imports/$jobId"
if [[ ! -d "$dir" ]]; then
  echo "Upload not found or expired: $jobId" >&2
  exit 1
fi
trap 'rm -rf "$dir"' EXIT

"$(dirname "$0")/prepare-import-dir.sh" "$dir"

beet import -t "$dir"
