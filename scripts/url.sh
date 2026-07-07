#!/usr/bin/env bash

set -euo pipefail

scripts_dir="$(dirname "$0")"
source "$scripts_dir/cleanup.sh"
cleanup_stale_download_dirs

url=
while [[ -z "$url" ]]; do
  read -r -p "URL: " url
done

tmpdir="$(mktemp -d -t beet-url.XXXXXX)"
cleanup_dir_on_exit "$tmpdir"

curl --fail --location --remote-name --remote-header-name --output-dir "$tmpdir" "$url"

"$scripts_dir/prepare-import-dir.sh" "$tmpdir"

beet import -t "$tmpdir"
