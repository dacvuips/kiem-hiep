#!/usr/bin/env python3
"""
Server HTTP cục bộ chuyên dụng cho Godot 4 Web.
1. Tự động thêm 2 headers bảo mật bắt buộc cho Godot 4 đa luồng:
   - Cross-Origin-Opener-Policy: same-origin
   - Cross-Origin-Embedder-Policy: require-corp
2. Proxy các request /v1/* về thẳng backend server (https://kiem-hiep-api.viettheo.site)
   để trình duyệt không bị lỗi CORS khi test cục bộ.
"""
import http.server
import socketserver
import os
import sys
import gzip
import urllib.request
import urllib.error
import webbrowser

PORT = 8088
BACKEND_HOST = "https://kiem-hiep-api.viettheo.site"
DEFAULT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))

# Nếu build/web chưa có index.html nhưng build/test_web có sẵn thì dùng test_web
if not os.path.exists(os.path.join(DEFAULT_DIR, "index.html")):
    fallback = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "test_web"))
    if os.path.exists(os.path.join(fallback, "index.html")):
        DEFAULT_DIR = fallback

class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DEFAULT_DIR, **kwargs)

    def end_headers(self):
        # Bắt buộc cho Godot 4 Web đa luồng (SharedArrayBuffer)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_proxy(self):
        target_url = BACKEND_HOST + self.path
        body = None
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > 0:
            body = self.rfile.read(content_length)

        # Chuyển tiếp headers
        req_headers = {}
        for k, v in self.headers.items():
            if k.lower() not in ["host", "origin", "referer", "content-length"]:
                req_headers[k] = v
        req_headers["Host"] = "kiem-hiep-api.viettheo.site"
        req_headers["Accept-Encoding"] = "identity"
        if not any(k.lower() == "user-agent" for k in req_headers):
            req_headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        def read_body(src):
            raw = src.read()
            if len(raw) >= 2 and raw[0] == 0x1F and raw[1] == 0x8B:
                try:
                    return gzip.decompress(raw)
                except Exception:
                    pass
            return raw

        req = urllib.request.Request(target_url, data=body, headers=req_headers, method=self.command)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                resp_data = read_body(resp)
                self.send_response(resp.status)
                for hk, hv in resp.headers.items():
                    if hk.lower() not in ["transfer-encoding", "content-encoding", "content-length", "access-control-allow-origin"]:
                        self.send_header(hk, hv)
                self.send_header("Content-Length", str(len(resp_data)))
                self.end_headers()
                self.wfile.write(resp_data)
        except urllib.error.HTTPError as e:
            err_data = read_body(e)
            self.send_response(e.code)
            for hk, hv in e.headers.items():
                if hk.lower() not in ["transfer-encoding", "content-encoding", "content-length", "access-control-allow-origin"]:
                    self.send_header(hk, hv)
            self.send_header("Content-Length", str(len(err_data)))
            self.end_headers()
            self.wfile.write(err_data)
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):
        if self.path.startswith("/v1/"):
            return self.do_proxy()
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith("/v1/"):
            return self.do_proxy()
        self.send_error(404)

    def do_PUT(self):
        if self.path.startswith("/v1/"):
            return self.do_proxy()
        self.send_error(404)

    def do_DELETE(self):
        if self.path.startswith("/v1/"):
            return self.do_proxy()
        self.send_error(404)

    def do_OPTIONS(self):
        if self.path.startswith("/v1/"):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")
            self.end_headers()
            return
        return super().do_OPTIONS()

if __name__ == "__main__":
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
        DEFAULT_DIR = os.path.abspath(sys.argv[1])

    if not os.path.exists(DEFAULT_DIR):
        print(f"[!] Thu muc build chua ton tai: {DEFAULT_DIR}")
        print(f"    Hay build game truoc bang Godot hoac CLI.")
        sys.exit(1)

    print("==================================================")
    print(f"  Godot 4 Web Server dang chay tai:")
    print(f"  -> http://localhost:{PORT}")
    print(f"  Thu muc: {DEFAULT_DIR}")
    print(f"  Proxy /v1/* -> {BACKEND_HOST}")
    print(f"  Nhan Ctrl+C de dung server.")
    print("==================================================")

    webbrowser.open(f"http://localhost:{PORT}/index.html")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), GodotWebHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nDa tat server.")
