#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(dirname "$0")"
source "$scripts_dir/cleanup.sh"
cleanup_stale_download_dirs

url=
while [[ -z "$url" ]]; do
  read -r -p "YouTube URL: " url
done

read -r -p "Split into chapters? [y/N]: " split_chapters
case "$split_chapters" in
[yY] | [yY][eE][sS]) split_chapters=yes ;;
*) split_chapters=no ;;
esac

tmpdir="$(mktemp -d -t beet-youtube.XXXXXX)"
cleanup_dir_on_exit "$tmpdir"

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

yt_dlp_args=(
  "${config_args[@]}"
  "${cookies_args[@]}"
  -f bestaudio
  --extract-audio
  --audio-format mp3
  --audio-quality 0
  --add-metadata
  --embed-thumbnail
  --ppa "EmbedThumbnail+ffmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\""
  --paths "$tmpdir"
  --output "%(title)s.%(ext)s"
  --remote-components ejs:github
  --js-runtimes "node:$node_bin"
  --progress
)

if [[ "$split_chapters" == yes ]]; then
  yt_dlp_args+=(
    --split-chapters
    --output "chapter:%(title)s/%(section_number)02d %(section_title)s.%(ext)s"
  )
fi

yt-dlp "${yt_dlp_args[@]}" "$url"

"$scripts_dir/prepare-import-dir.sh" "$tmpdir"

if [[ "$split_chapters" == yes ]]; then
  find "$tmpdir" -maxdepth 1 -type f -iname '*.mp3' -print0 |
    while IFS= read -r -d '' full_file; do
      chapter_dir="${full_file%.*}"
      if [[ -d "$chapter_dir" ]] &&
        find "$chapter_dir" -type f -iname '*.mp3' -print -quit | grep -q .; then
        rm -f -- "$full_file"
      fi
    done

  "$scripts_dir/tag-youtube-chapters.sh" "$tmpdir"
fi

beet import -t "$tmpdir"
