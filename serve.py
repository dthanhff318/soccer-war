#!/usr/bin/env python3
"""Local server for the Godot web export.

Godot's web builds use SharedArrayBuffer when thread support is enabled, which
browsers only expose to cross-origin-isolated pages. A plain static server
(python -m http.server) omits the required headers and the game fails to boot,
so this adds COOP/COEP to every response.

Usage:
    python3 serve.py [port]        # defaults to 8060, serves ./export
"""

import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

DEFAULT_PORT = 8060
EXPORT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")


class CrossOriginIsolatedHandler(SimpleHTTPRequestHandler):
    """Static handler that marks responses as cross-origin isolated."""

    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".wasm": "application/wasm",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT

    if not os.path.isdir(EXPORT_DIR):
        print(f"error: {EXPORT_DIR} does not exist — run the Godot web export first.")
        return 1
    if not os.path.isfile(os.path.join(EXPORT_DIR, "index.html")):
        print("error: export/index.html not found — export from Godot with the 'Web' preset.")
        return 1

    handler = partial(CrossOriginIsolatedHandler, directory=EXPORT_DIR)
    with ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"Serving {EXPORT_DIR} at http://127.0.0.1:{port}/  (Ctrl+C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
