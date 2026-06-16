#!/usr/bin/env bash

set -euo pipefail

url=
while [[ -z "$url" ]]; do
  read -r -p "URL: " url
done

tmpdir="$(mktemp -d -t beet-url.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

config_args=(--ignore-config)
if [[ -f /config/yt-dlp/config ]]; then
  config_args+=(--config-locations /config/yt-dlp/config)
fi

cookies_args=()
if [[ -f /config/yt-dlp/cookies.txt ]]; then
  cookies_args=(--cookies /config/yt-dlp/cookies.txt)
fi

node_bin="$(command -v node)"

yt-dlp \
  "${config_args[@]}" \
  "${cookies_args[@]}" \
  -f bestaudio \
  --extract-audio \
  --paths "$tmpdir" \
  --output "%(title)s.%(ext)s" \
  --remote-components ejs:github \
  --js-runtimes "node:$node_bin" \
  "$url"

beet import -t "$tmpdir"
