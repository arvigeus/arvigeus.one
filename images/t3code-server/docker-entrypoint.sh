#!/usr/bin/env bash
set -euo pipefail

T3_UID="${PUID:-1000}"
T3_GID="${PGID:-1000}"
APP_USER=node

if [ "$(id -u)" = "0" ]; then
  current_gid="$(id -g "$APP_USER")"
  if [ "$T3_GID" != "$current_gid" ]; then
    if getent group "$T3_GID" >/dev/null; then
      usermod -g "$T3_GID" "$APP_USER"
    else
      groupmod -g "$T3_GID" "$(id -gn "$APP_USER")"
    fi
  fi

  current_uid="$(id -u "$APP_USER")"
  if [ "$T3_UID" != "$current_uid" ]; then
    usermod -u "$T3_UID" "$APP_USER"
  fi

  mkdir -p "$T3CODE_HOME" "$T3CODE_WORKSPACE" "$HOME"
  chown -R "$APP_USER:$(id -gn "$APP_USER")" "$T3CODE_HOME" "$T3CODE_WORKSPACE" "$HOME"
  exec gosu "$APP_USER" "$0" "$@"
fi

cd /opt/t3code

if [ -n "${T3CODE_PUBLIC_URL:-}" ]; then
  echo
  echo "T3Code hosted UI pairing:"
  echo "  Go to: https://t3code.web.app/pair"
  echo "  Field 1 - Pairing URL: copy the pairingUrl printed by the server below"
  echo "  Field 2 - Actual server URL: ${T3CODE_PUBLIC_URL}"
  echo
fi

exec bun run apps/server/src/bin.ts start \
  --host "$T3CODE_HOST" \
  --port "$T3CODE_PORT" \
  --base-dir "$T3CODE_HOME" \
  --no-browser \
  "$T3CODE_WORKSPACE"
