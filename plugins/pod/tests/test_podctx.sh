#!/usr/bin/env bash
# Tests for bin/podctx, with fake pod, op, curl and docker commands: no network, no Pod.
# Run: bash plugins/pod/tests/test_podctx.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
podctx="$here/../bin/podctx"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

KEY="pod_$(printf 'a%.0s' $(seq 43))"
fails=0; passes=0
ok()   { passes=$((passes + 1)); }
fail() { fails=$((fails + 1)); echo "FAIL: $1"; }

# --- fakes -----------------------------------------------------------------------------------
mkdir -p "$work/bin" "$work/proj/.pod" "$work/proj/sub" "$work/empty"
cat > "$work/bin/pod" <<'EOF'
#!/usr/bin/env bash
# Fake Pod CLI: `help` mentions POD_URL; anything else records argv and environment.
if [ "${1:-}" = help ]; then echo "set POD_URL and POD_API_KEY"; exit 0; fi
{ echo "argv: $*"; echo "url: $POD_URL"; echo "service: ${POD_SERVICE:-}"
  [ "$POD_API_KEY" = "$EXPECTED_KEY" ] && echo "key: ok" || echo "key: wrong"; } > "$LOG"
exit "${FAKE_RC:-0}"
EOF
cat > "$work/bin/op" <<'EOF'
#!/usr/bin/env bash
# Fake 1Password CLI: `op read -n op://T/pod/credential` prints the test key.
[ "$1 $2" = "read -n" ] && [ "$3" = "op://T/pod/credential" ] && { printf '%s' "$EXPECTED_KEY"; exit 0; }
echo "[ERROR] not found" >&2; exit 1
EOF
cat > "$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Fake curl: records argv and the content of any -H @file header.
: > "$LOG"
while [ $# -gt 0 ]; do
  echo "arg: $1" >> "$LOG"
  if [ "$1" = -H ] && [ "${2:0:1}" = @ ]; then echo "hdrfile: $(cat "${2#@}")" >> "$LOG"; fi
  shift
done
echo '{"ok":true}'
EOF
chmod +x "$work/bin/"*

cat > "$work/instances" <<EOF
# comment
[acme]
url = https://pod.acme.example/   # trailing slash dropped
key = op://T/pod/credential

[beta]
url = https://pod.beta.example
key = env:BETA_KEY

[clear]
url = https://pod.clear.example
key = $KEY

[nokey]
url = https://pod.nokey.example
EOF
printf '{\n  "app": "shop",\n  "instance": "acme",\n  "service": "shop/web"\n}\n' > "$work/proj/.pod/app.json"

export PATH="$work/bin:$PATH" POD_INSTANCES_FILE="$work/instances" EXPECTED_KEY="$KEY" LOG="$work/log"
unset POD_SERVICE POD_BIN POD_OP BETA_KEY 2>/dev/null || true

run() { out="$("$podctx" "$@" 2>&1)"; rc=$?; }
expect_rc()  { [ "$rc" -eq "$1" ] && ok || fail "$2 (rc=$rc, want $1): $out"; }
expect_out() { case "$out" in *"$1"*) ok ;; *) fail "$2: output lacks '$1': $out" ;; esac; }
expect_log() { grep -qF -- "$1" "$LOG" && ok || fail "$2: log lacks '$1': $(cat "$LOG")"; }
no_key_in()  { case "$1" in *"$KEY"*) fail "$2: the key leaked" ;; *) ok ;; esac; }

# --- tests -----------------------------------------------------------------------------------
run instances
expect_rc 0 "instances"
expect_out "acme	https://pod.acme.example/	key: 1password" "instances lists acme"
expect_out "key: IN CLEAR (refused)" "instances flags a clear key"
no_key_in "$out" "instances"

run acme deploy --detach
expect_rc 0 "pod via 1Password key"
expect_log "argv: deploy --detach" "argv passed through"
expect_log "url: https://pod.acme.example" "url without trailing slash"
expect_log "key: ok" "key in the environment"
no_key_in "$(grep argv "$LOG")" "argv"
no_key_in "$out" "pod output"

FAKE_RC=1 run acme deploy
expect_rc 1 "the CLI's exit status is kept"

BETA_KEY="$KEY" run beta -- ls --json
expect_rc 0 "env: key"
expect_log "argv: ls --json" "-- separator dropped"

run beta ls
expect_rc 3 "empty env: key"
expect_out "BETA_KEY is empty" "empty env message"

run clear ls
expect_rc 3 "clear key refused"
no_key_in "$out" "clear key message"

run nokey ls
expect_rc 3 "missing key line"

run nowhere ls
expect_rc 3 "unknown instance"
expect_out "unknown instance 'nowhere'" "unknown instance message"

# Subshells would lose the counters: change directory in place.
cd "$work/proj/sub"
run . status
expect_rc 0 ". from app.json"
expect_log "service: shop/web" "service from app.json"
run acme status
expect_log "service: shop/web" "service when the instance matches app.json"
BETA_KEY="$KEY" run beta status
grep -q "shop/web" "$LOG" && fail "app.json service leaked to another instance" || ok
POD_SERVICE=other/svc run . status
expect_log "service: other/svc" "POD_SERVICE wins"
cd "$work/proj"
run here
expect_out "instance	acme" "here"
expect_out "service	shop/web" "here service"
cd "$work/empty"
run . status
expect_rc 3 ". without app.json"
cd "$here"

run acme api GET /api/v1/version
expect_rc 0 "api GET"
expect_log "arg: https://pod.acme.example/api/v1/version" "api URL"
expect_log "hdrfile: Authorization: Bearer $KEY" "key sent in a header file"
no_key_in "$(grep '^arg:' "$LOG")" "curl argv"

run acme api get https://evil.example/api/v1/x
expect_rc 2 "api refuses a foreign URL"

run acme api POST /api/v1/services/x/deploy "$work/missing.json"
expect_rc 2 "api missing body file"

echo '{}' > "$work/body.json"
run acme api post /api/v1/services/x/deploy "$work/body.json"
expect_rc 0 "api POST with a body"
expect_log "arg: POST" "method upper-cased"
expect_log "arg: @$work/body.json" "body file"

# The CLI from an image when no pod binary answers to `pod help`.
rm "$work/bin/pod"
cat > "$work/bin/docker" <<'EOF'
#!/usr/bin/env bash
echo "argv: $*" > "$LOG"; [ "$POD_API_KEY" = "$EXPECTED_KEY" ] && echo "key: ok" >> "$LOG"
EOF
chmod +x "$work/bin/docker"
printf '\n[img]\nurl = https://pod.img.example\nkey = op://T/pod/credential\nimage = reg.example/pod:0.26.1\n' >> "$work/instances"
run img version
expect_rc 0 "docker image"
expect_log "argv: run --rm -i -e POD_URL -e POD_API_KEY -e POD_SERVICE -e POD_ALLOW_HTTP reg.example/pod:0.26.1 version" "docker argv"
expect_log "key: ok" "docker key in the environment"

run acme version
expect_rc 3 "no CLI and no image"
expect_out "no Pod CLI" "no CLI message"

echo "$passes passed, $fails failed"
[ "$fails" -eq 0 ]
