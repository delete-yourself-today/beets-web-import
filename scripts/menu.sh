#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(dirname "$0")"

printf '\e[1mImport with beets\e[0m\n'
printf '  \e[1m1\e[0m) Import from /inbox\n'
printf '  \e[1m2\e[0m) Download from URL\n'
printf '  ...or drag and drop anywhere in this window to upload\n'
printf '\n'

while true; do
  IFS= read -r -n 1 choice || exit 0
  printf '\n'
  case "$choice" in
  1)
    printf '\e[2mStarting beets import from /inbox...\e[0m\n'
    exec "$scripts_dir/inbox.sh"
    ;;
  2)
    printf '\e[2mStarting URL import...\e[0m\n'
    exec "$scripts_dir/url.sh"
    ;;
  esac
done
