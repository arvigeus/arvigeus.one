#!/bin/bash

set -euo pipefail

# Load environment variables from project root.
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' "../../.env" | grep -v '^$')
set +a

: "${DATA:?DATA is not set in .env}"
: "${OPENCODE_WORKSPACE:?OPENCODE_WORKSPACE is not set in .env}"
: "${PUID:?PUID is not set in .env}"
: "${PGID:?PGID is not set in .env}"

sudo mkdir -p "$DATA/opencode/home" "$OPENCODE_WORKSPACE"
sudo chown -R "$PUID:$PGID" "$DATA/opencode" "$OPENCODE_WORKSPACE"
