#!/usr/bin/env bash

set -euo pipefail

url=
while [[ -z "$url" ]]; do
  read -r -p "URL: " url
done

tmpdir="$(mktemp -d -t beet-url.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

curl --fail --location --remote-name --remote-header-name --output-dir "$tmpdir" "$url"

"$(dirname "$0")/prepare-import-dir.sh" "$tmpdir"

beet import -t "$tmpdir"
