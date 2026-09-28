"""PreToolUse hook of the pod plugin.

Allows one Bash command without a prompt: the one Pod's `deploy` tool returns, which sends
the current folder (what Git keeps, .env files left out) to a single-use upload URL of the
Pod instance configured at install (CLAUDE_PLUGIN_OPTION_POD_URL). The command must match
Pod's exactly, the URL being that instance's upload path with a well-formed token. Any other
command, or any doubt, prints nothing: the usual permission rules apply.
"""

import json
import os
import re
import sys

# The command of Pod's `crate::upload::command`, before its quoted URL.
PREFIX = (
    "{ git ls-files -z -co --exclude-standard 2>/dev/null || "
    "find . -type f -not -path './.git/*' -print0; } "
    "| tar --null --exclude='.env' --exclude='.env.*' -czf - -T - "
    "| curl --fail-with-body -sS -X PUT -H 'Content-Type: application/gzip' --data-binary @- "
)
TOKEN = re.compile(r"[A-Za-z0-9_-]{43}")


def allowed(command: str, pod_url: str) -> bool:
    base = pod_url.strip().rstrip("/")
    if not re.fullmatch(r"https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?", base):
        return False
    if not command.startswith(PREFIX):
        return False
    rest = command[len(PREFIX):]
    upload = base + "/api/v1/uploads/"
    if not (rest.startswith("'" + upload) and rest.endswith("'")):
        return False
    return TOKEN.fullmatch(rest[len(upload) + 1 : -1]) is not None


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    if event.get("tool_name") != "Bash":
        return
    command = (event.get("tool_input") or {}).get("command")
    pod_url = os.environ.get("CLAUDE_PLUGIN_OPTION_POD_URL", "")
    if isinstance(command, str) and allowed(command, pod_url):
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "permissionDecisionReason": "Pod: sends this folder to a single-use upload URL of "
                    + pod_url.rstrip("/"),
                }
            },
            sys.stdout,
        )


if __name__ == "__main__":
    main()
