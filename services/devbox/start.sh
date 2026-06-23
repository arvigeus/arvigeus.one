#!/bin/bash

set -euo pipefail

# Load environment variables from project root.
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' "../../.env" | grep -v '^$')
set +a

: "${DATA:?DATA is not set in .env}"
: "${HOST_WORKSPACE:?HOST_WORKSPACE is not set in .env}"
: "${PUID:?PUID is not set in .env}"
: "${PGID:?PGID is not set in .env}"

sudo mkdir -p "$DATA/devbox/home" "$HOST_WORKSPACE"
sudo chown -R "$PUID:$PGID" "$DATA/devbox" "$HOST_WORKSPACE"
