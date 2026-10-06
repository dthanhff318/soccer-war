#!/usr/bin/env bash
# End-to-end check: starts a server, then a host bot and a guest bot that go
# through menu -> lobby -> match and verify movement and prediction.
set -uo pipefail
cd "$(dirname "$0")/.."
PORT=9444
CODE_FILE="$(mktemp -u)"
PORT=$PORT godot --headless -- --server > /dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -f "$CODE_FILE"' EXIT
sleep 2
run_bot() {
	perl -e 'alarm 90; exec @ARGV' godot --headless -s tools/e2e_bot.gd -- \
		--role="$1" --code-file="$CODE_FILE" --url=ws://127.0.0.1:$PORT 2>&1 | grep -E "E2E|SCRIPT ERROR|ERROR"
}
run_bot host & HOST=$!
run_bot guest & GUEST=$!
wait $HOST; wait $GUEST
