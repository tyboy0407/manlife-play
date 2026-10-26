"""本機預覽網頁版:python tools/serve_web.py [--port 8080] [--dir build/web]
在所有網卡上開,終端機印出電腦與 iPhone(同一個 Wi-Fi)可用的網址。wasm / pck 給正確的 MIME,全部不快取。
目前用的是「不開執行緒」的匯出模板,所以不需要 COOP / COEP 標頭;若改成有執行緒的模板,把下面兩行註解打開。
"""
import argparse
import os
import socket
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript; charset=utf-8",
        ".json": "application/json; charset=utf-8",
        ".webmanifest": "application/manifest+json; charset=utf-8",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        # self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        # self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, fmt, *args):
        if "200" in str(args) or "304" in str(args):
            return
        super().log_message(fmt, *args)


def lan_ips():
    ips = set()
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ip = info[4][0]
            if not ip.startswith("127."):
                ips.add(ip)
    except socket.gaierror:
        pass
    return sorted(ips)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=int(os.environ.get("PORT", "8080")))
    ap.add_argument("--dir", default=os.path.join(ROOT, "build", "web"))
    args = ap.parse_args()
    if not os.path.isfile(os.path.join(args.dir, "index.html")):
        raise SystemExit("找不到 %s/index.html,先匯出:python tools/deploy_web.py --export-only" % args.dir)
    server = ThreadingHTTPServer(("0.0.0.0", args.port), partial(Handler, directory=args.dir))
    print("ManLife web preview")
    print("  本機:   http://localhost:%d/" % args.port)
    for ip in lan_ips():
        print("  iPhone: http://%s:%d/   (同一個 Wi-Fi)" % (ip, args.port))
    print("Ctrl+C 結束")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
