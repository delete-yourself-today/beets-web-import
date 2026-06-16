#!/usr/bin/env bash

set -euo pipefail

dir="$1"

find "$dir" -maxdepth 1 -type f -iname '*.zip' -print0 |
  while IFS= read -r -d '' archive; do
    extract_dir="${archive%.*}"
    mkdir -p "$extract_dir"
    unzip -oq "$archive" -d "$extract_dir"
    rm -f "$archive"
  done
