"""Serve build/web the way a real host does, for local testing.

    flutter build web --release
    python tool/serve_web.py

Then open http://127.0.0.1:8080

Python's own http.server is not good enough on its own: it 404s any path that
is not a file on disk, and `/payment-callback` is not a file. Paystack sends a
paying student there, so without the fallback below every successful payment
would look like a broken link locally — a bug you would then go hunting for in
the app instead of in the server.
"""

import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class SinglePageApp(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        path = self.translate_path(self.path)
        # A request with no file extension is a route, not an asset: hand it
        # index.html and let the app decide what it means.
        if not os.path.exists(path) and "." not in os.path.basename(path):
            self.path = "/index.html"
        return super().send_head()

    def end_headers(self):
        # Never cache during testing, or a rebuild appears to change nothing.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    if not os.path.isdir(ROOT):
        sys.exit("No build/web yet. Run:  flutter build web --release")
    os.chdir(ROOT)
    print(f"PadiLearn web  ->  http://127.0.0.1:{PORT}")
    print(f"Payment callback test  ->  http://127.0.0.1:{PORT}/payment-callback?reference=fake")
    print("Ctrl+C to stop.")
    # Threading, not plain HTTPServer: Chrome opens spare connections it may
    # never use, and a single-threaded server blocks on the first idle one,
    # so the page stalls after a few files.
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), SinglePageApp).serve_forever()
