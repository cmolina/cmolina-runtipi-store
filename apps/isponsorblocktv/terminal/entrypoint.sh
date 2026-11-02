#!/bin/sh
# Security invariant: ttyd execs the command directly (no shell), so the web
# terminal can only ever run the setup wizard - no arbitrary commands.
set -eu

# -m 1 caps it at one client; -o (exit on disconnect) killed ttyd after the
# first visit, leaving the next one with a dead terminal during the restart.
exec ttyd -W -m 1 -p 7681 python3 -u main.pyc --setup-cli
