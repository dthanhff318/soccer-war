#!/usr/bin/env bash
# Exports the web build to export/. The build is committed: pushing to main
# makes Vercel serve export/ as-is (see vercel.json), so run this before
# every commit that touches the game.
set -euo pipefail
cd "$(dirname "$0")/.."
if grep -q '^const PRODUCTION_URL := ""' scripts/net/protocol.gd; then
	echo "WARNING: PRODUCTION_URL in scripts/net/protocol.gd is empty." >&2
	echo "         This build only finds a server on localhost or via ?server=wss://..." >&2
	echo "         Set it to your Render URL (wss://...) before deploying to Vercel." >&2
fi
godot --headless --export-release "Web" export/index.html
echo "Web build ready in export/"
