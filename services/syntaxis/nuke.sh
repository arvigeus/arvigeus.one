#!/bin/bash

set -euo pipefail

# Load the deployment data path from the project root.
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' "../../.env" | grep -v '^$')
set +a

: "${DATA:?DATA is not set in .env}"

home="$DATA/syntaxis/home"
if [ ! -d "$home" ]; then
	echo "Syntaxis home does not exist; nothing to clean: $home"
	exit 0
fi

# Refuse broad or unexpected targets before any removal. Resolve DATA even when
# it is relative to this service directory, just as Compose and start.sh do.
data_real=$(realpath -m "$DATA")
home_real=$(realpath -m "$home")
case "$home_real" in
"$data_real"/syntaxis/home) ;;
*)
	echo "ERROR: Refusing to clean unexpected Syntaxis home: $home_real" >&2
	exit 1
	;;
esac

was_running=false
if command -v docker >/dev/null 2>&1 && [ "$(docker inspect -f '{{.State.Running}}' syntaxis 2>/dev/null || true)" = true ]; then
	echo "Stopping Syntaxis while its persistent runtime files are cleaned..."
	docker stop syntaxis >/dev/null
	was_running=true
fi

restart_syntaxis() {
	if [ "$was_running" = true ]; then
		echo "Starting Syntaxis..."
		docker start syntaxis >/dev/null
	fi
}
trap restart_syntaxis EXIT

echo "Removing reproducible downloads, toolchains, package caches, and temporary files from $home_real"

# Keep credentials, shell/editor configuration, AI state, and /Projects. Every
# path below contains only downloaded packages, installed runtimes, or caches.
paths=(
	.cache
	.bun
	.cargo/git
	.cargo/registry
	.deno
	.gradle/caches
	.gradle/daemon
	.gradle/native
	.gradle/notifications
	.gradle/wrapper/dists
	.local/share/mise
	.npm/_cacache
	.npm/_logs
	.npm/_npx
	.nuget/packages
	.pnpm-store
	.rustup
	.yarn/cache
	.yarn/unplugged
	go/pkg/mod
	go/pkg/sumdb
	tmp
)

removed=0
for relative in "${paths[@]}"; do
	target="$home_real/$relative"
	if [ -e "$target" ] || [ -L "$target" ]; then
		sudo rm -rf -- "$target"
		echo "  removed $relative"
		removed=$((removed + 1))
	fi
done

echo "Syntaxis cleanup complete: removed $removed cache/runtime path(s)."
