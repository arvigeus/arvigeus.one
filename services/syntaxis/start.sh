#!/bin/bash

set -euo pipefail

# Load environment variables from the project root.
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' "../../.env" | grep -v '^$')
set +a

: "${DATA:?DATA is not set in .env}"
: "${HOST_HOME:?HOST_HOME is not set in .env}"
: "${PUID:?PUID is not set in .env}"
: "${PGID:?PGID is not set in .env}"

host_projects="${HOST_PROJECTS:-$HOST_HOME/Projects}"

sudo mkdir -p "$DATA/syntaxis/home" "$host_projects"
sudo chown -R "$PUID:$PGID" "$DATA/syntaxis"
sudo chown "$PUID:$PGID" "$host_projects"
