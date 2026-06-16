#!/usr/bin/env bash

set -euo pipefail

url=
while [[ -z "$url" ]]; do
  read -r -p "Apple Music URL: " url
done

tmpdir="$(mktemp -d -t beet-gamdl.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

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

"$(dirname "$0")/prepare-import-dir.sh" "$tmpdir"

beet import -t "$tmpdir"
