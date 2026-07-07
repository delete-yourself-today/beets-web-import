#!/usr/bin/env bash

set -euo pipefail

url=
while [[ -z "$url" ]]; do
  read -r -p "YouTube URL: " url
done

tmpdir="$(mktemp -d -t beet-youtube.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

config_args=(--ignore-config)
if [[ -f /config/yt-dlp/config ]]; then
  config_args+=(--config-locations /config/yt-dlp/config)
fi

cookies_args=()
if [[ -f /config/yt-dlp/cookies.txt ]]; then
  cookies_file="$tmpdir/cookies.txt"
  cp /config/yt-dlp/cookies.txt "$cookies_file"
  chmod 600 "$cookies_file"
  cookies_args=(--cookies "$cookies_file")
fi

node_bin="$(command -v node)"

yt-dlp \
  "${config_args[@]}" \
  "${cookies_args[@]}" \
  -f bestaudio \
  --extract-audio \
  --audio-format mp3 \
  --audio-quality 0 \
  --add-metadata \
  --split-chapters \
  --embed-thumbnail \
  --ppa "EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" \
  --paths "$tmpdir" \
  --output "%(title)s.%(ext)s" \
  --output "chapter:%(title)s/%(section_number)02d %(section_title)s.%(ext)s" \
  --remote-components ejs:github \
  --js-runtimes "node:$node_bin" \
  --progress \
  "$url"

"$(dirname "$0")/prepare-import-dir.sh" "$tmpdir"

beet import -t "$tmpdir"
