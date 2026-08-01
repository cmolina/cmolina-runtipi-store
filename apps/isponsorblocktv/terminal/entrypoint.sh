#!/bin/sh
# Security invariant: ttyd execs the command directly (no shell), so the web
# terminal can only ever run the setup wizard - no arbitrary commands.
set -eu

exec ttyd -W -o -p 7681 python3 -u main.pyc --setup-cli
