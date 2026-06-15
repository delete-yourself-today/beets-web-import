#!/usr/bin/env bash

set -euo pipefail

url=
while [[ -z "$url" ]]; do
  read -r -p "URL: " url
done

tmpdir="$(mktemp -d -t beet-url.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

yt-dlp \
  --cookies "$HOME/.config/beets/cookies.txt" \
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
  --js-runtimes node:/usr/bin/node \
  "$url"

beet import -t "$tmpdir"
