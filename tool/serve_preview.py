"""Serve the local Flutter preview with safe, durable Drift web storage headers.

Run from the project root: python tool/serve_preview.py --port 8765
Local development only; this is not a public production hosting service.
"""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class PreviewHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript; charset=utf-8",
        ".json": "application/json; charset=utf-8",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--directory", default="build/web")
    args = parser.parse_args()
    root = Path(args.directory).resolve()
    if not (root / "index.html").is_file():
        parser.error("Build the web app first: flutter build web --no-web-resources-cdn")
    server = ThreadingHTTPServer(
        ("127.0.0.1", args.port), partial(PreviewHandler, directory=str(root))
    )
    print(f"FindIt preview: http://127.0.0.1:{args.port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
