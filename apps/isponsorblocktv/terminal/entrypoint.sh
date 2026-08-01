#!/bin/sh
# Security invariant: ttyd execs the command directly (no shell), so the web
# terminal can only ever run the setup wizard - no arbitrary commands.
# TERMINAL_PASSWORD (Runtipi form field) becomes ttyd Basic Auth (user: setup).
set -eu

PASSWORD="${TERMINAL_PASSWORD:-}"

if [ -n "${PASSWORD}" ]; then
  exec ttyd -W -o -p 7681 -c "setup:${PASSWORD}" python3 -u main.pyc --setup-cli
else
  exec ttyd -W -o -p 7681 python3 -u main.pyc --setup-cli
fi
