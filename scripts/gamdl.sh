#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(dirname "$0")"
source "$scripts_dir/cleanup.sh"
cleanup_stale_download_dirs

url=
while [[ -z "$url" ]]; do
  read -r -p "Apple Music URL: " url
done

tmpdir="$(mktemp -d -t beet-gamdl.XXXXXX)"
cleanup_dir_on_exit "$tmpdir"

config_args=()
if [[ -f /config/gamdl/config.ini ]]; then
  config_args=(--config-path /config/gamdl/config.ini)
else
  config_args=(--no-config-file)
fi

cookies_args=()
if [[ -f /config/gamdl/cookies.txt ]]; then
  cookies_args=(--cookies-path /config/gamdl/cookies.txt)
fi

gamdl \
  "${config_args[@]}" \
  "${cookies_args[@]}" \
  --no-synced-lyrics \
  --output-path "$tmpdir" \
  -- \
  "$url"

"$scripts_dir/prepare-import-dir.sh" "$tmpdir"

beet import -t "$tmpdir"
