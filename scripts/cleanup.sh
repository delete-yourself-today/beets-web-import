#!/usr/bin/env bash

cleanup_dir_on_exit() {
  local dir="$1"
  local quoted_dir
  printf -v quoted_dir '%q' "$dir"

  trap "rm -rf -- $quoted_dir" EXIT
  trap "trap - EXIT HUP INT TERM; rm -rf -- $quoted_dir; exit 129" HUP
  trap "trap - EXIT HUP INT TERM; rm -rf -- $quoted_dir; exit 130" INT
  trap "trap - EXIT HUP INT TERM; rm -rf -- $quoted_dir; exit 143" TERM
}

cleanup_stale_download_dirs() {
  local tmp_root="${TMPDIR:-/tmp}"

  find "$tmp_root" -mindepth 1 -maxdepth 1 -type d \( \
    -name 'beet-gamdl.*' -o \
    -name 'beet-url.*' -o \
    -name 'beet-youtube.*' \
  \) -exec rm -rf -- {} +
}
