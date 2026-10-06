#!/usr/bin/env bash
# Exports the web build to export/ and adds the Vercel config (COOP/COEP
# headers needed by Godot's threaded web build). Deploy with:
#   vercel deploy export --prod
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --export-release "Web" export/index.html
cp web/vercel.json export/vercel.json
echo "Web build ready in export/"
