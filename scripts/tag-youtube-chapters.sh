#!/usr/bin/env bash

set -euo pipefail

root_dir="$1"

find "$root_dir" -mindepth 1 -maxdepth 1 -type d -print0 |
  while IFS= read -r -d '' chapter_dir; do
    mapfile -d '' chapter_files < <(
      find "$chapter_dir" -maxdepth 1 -type f -iname '*.mp3' -print0 | sort -z
    )

    track_total="${#chapter_files[@]}"
    if ((track_total == 0)); then
      continue
    fi

    for chapter_file in "${chapter_files[@]}"; do
      filename="$(basename "$chapter_file")"
      stem="${filename%.*}"

      if [[ "$stem" =~ ^([0-9]+)[[:space:]]+(.+)$ ]]; then
        track_number="$((10#${BASH_REMATCH[1]}))"
        title="${BASH_REMATCH[2]}"
      else
        echo "Cannot determine chapter number from: $chapter_file" >&2
        exit 1
      fi

      tagged_file="${chapter_file%.*}.tagged.mp3"
      rm -f -- "$tagged_file"

      ffmpeg -nostdin -hide_banner -loglevel error \
        -i "$chapter_file" \
        -map 0 -c copy -map_metadata 0 \
        -metadata title="$title" \
        -metadata track="$track_number/$track_total" \
        "$tagged_file"

      mv -f -- "$tagged_file" "$chapter_file"
    done
  done
