#!/bin/sh
# Lets the command Pod's deploy tool gives run without a permission prompt: that exact
# command, sending the current folder to a single-use upload URL of the configured Pod
# instance. Anything else is left to the usual permission rules. Needs python3; without it,
# nothing is decided here.
command -v python3 >/dev/null 2>&1 || exit 0
exec python3 "$(dirname "$0")/allow_upload.py"
