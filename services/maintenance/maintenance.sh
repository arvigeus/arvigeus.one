#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
	echo "ERROR: Maintenance must run as root." >&2
	exit 1
fi

echo "Removing stopped containers older than 7 days..."
docker container prune -f --filter "until=168h"

echo "Removing unused images older than 30 days..."
docker image prune -a -f --filter "until=720h"

echo "Removing unused networks older than 7 days..."
docker network prune -f --filter "until=168h"

echo "Bounding Docker build cache at 2 GB..."
docker buildx prune -f --max-used-space 2gb

echo "Vacuuming systemd journal to 30 days and 1 GB..."
journalctl --vacuum-time=30d --vacuum-size=1G

if command -v apt-get >/dev/null 2>&1; then
	echo "Cleaning downloaded APT packages..."
	apt-get clean
fi

echo "Maintenance complete."
df -h /
docker system df
