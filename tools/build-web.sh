#!/usr/bin/env bash
# Exports the web build to export/ and adds the Vercel config (COOP/COEP
# headers needed by Godot's threaded web build). Deploy with:
#   vercel deploy export --prod
set -euo pipefail
cd "$(dirname "$0")/.."
if grep -q '^const PRODUCTION_URL := ""' scripts/net/protocol.gd; then
	echo "WARNING: PRODUCTION_URL in scripts/net/protocol.gd is empty." >&2
	echo "         This build only finds a server on localhost or via ?server=wss://..." >&2
	echo "         Set it to your Render URL (wss://...) before deploying to Vercel." >&2
fi
godot --headless --export-release "Web" export/index.html
cp web/vercel.json export/vercel.json
echo "Web build ready in export/"
