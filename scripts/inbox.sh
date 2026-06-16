#!/usr/bin/env bash

set -euo pipefail

"$(dirname "$0")/prepare-import-dir.sh" /inbox

exec beet import -t /inbox
