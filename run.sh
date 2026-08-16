#!/bin/bash

set -euo pipefail

RUN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$RUN_DIR"

ENV=.env # Do not touch
# Keep targeted Compose operations in the same project as full-stack operations.
# This matches the project label on the existing VPS containers.
COMPOSE_PROJECT="caddy"

# shellcheck source=scripts/common.sh
source "$RUN_DIR/scripts/common.sh"
# shellcheck source=scripts/lifecycle.sh
source "$RUN_DIR/scripts/lifecycle.sh"
# shellcheck source=scripts/maintenance.sh
source "$RUN_DIR/scripts/maintenance.sh"
# shellcheck source=scripts/nuke.sh
source "$RUN_DIR/scripts/nuke.sh"
# shellcheck source=scripts/smoke.sh
source "$RUN_DIR/scripts/smoke.sh"

function default {
	help
}

function help {
	echo "$0 <task> <args>"
	echo "Tasks:"
	printf '%s\n' cleanup maintenance nuke prune-stale start stop restart update smoke status info space help | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time "${@:-default}"
