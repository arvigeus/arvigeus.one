#!/usr/bin/env bash
set -euo pipefail

IMAGE="arvigeus/t3code-server"
PLATFORM="linux/amd64"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCKER="${DOCKER:-docker}"

read -r -p "Version: " VERSION

if [[ -z "${VERSION}" ]]; then
  echo "Version is required." >&2
  exit 1
fi

if "${DOCKER}" buildx build --help 2>&1 | grep -q -- "--push"; then
  "${DOCKER}" buildx build \
    --platform "${PLATFORM}" \
    -t "${IMAGE}:${VERSION}" \
    -t "${IMAGE}:latest" \
    --push \
    "${SCRIPT_DIR}"
else
  "${DOCKER}" build \
    --platform "${PLATFORM}" \
    -t "${IMAGE}:${VERSION}" \
    -t "${IMAGE}:latest" \
    "${SCRIPT_DIR}"

  "${DOCKER}" push "${IMAGE}:${VERSION}"
  "${DOCKER}" push "${IMAGE}:latest"
fi
