#!/usr/bin/env bash
set -euo pipefail

IMAGE="arvigeus/t3code-server"
PLATFORM="linux/amd64"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

read -r -p "Version: " VERSION

if [[ -z "${VERSION}" ]]; then
  echo "Version is required." >&2
  exit 1
fi

docker buildx build \
  --platform "${PLATFORM}" \
  -t "${IMAGE}:${VERSION}" \
  -t "${IMAGE}:latest" \
  --push \
  "${SCRIPT_DIR}"
