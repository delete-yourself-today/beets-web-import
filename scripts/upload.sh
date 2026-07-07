#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(dirname "$0")"
source "$scripts_dir/cleanup.sh"

jobId="$1"

dir="${TMPDIR:-/tmp}/beet-imports/$jobId"
if [[ ! -d "$dir" ]]; then
  echo "Upload not found or expired: $jobId" >&2
  exit 1
fi
cleanup_dir_on_exit "$dir"

"$scripts_dir/prepare-import-dir.sh" "$dir"

beet import -t "$dir"
