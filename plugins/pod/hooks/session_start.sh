#!/usr/bin/env bash
# SessionStart: puts the plugin's bin/ (podctx) on the PATH of the session's Bash tool.
# Prints nothing, so it costs no context; never reads a key or touches the network.
set -u
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  printf 'export PATH="%s/bin:$PATH"\n' "$CLAUDE_PLUGIN_ROOT" >> "$CLAUDE_ENV_FILE"
fi
exit 0
