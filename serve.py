#!/usr/bin/env python3
"""Cozy Shop 网页版本地服务器。

自动设置 Godot Web 所需的跨源隔离（COOP/COEP）响应头与 MIME 类型。
用法：python3 serve.py [端口]   （默认 8080）
"""
import http.server
import mimetypes
import os
import socketserver
import sys

# Godot Web 需要的 MIME 类型
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("text/html", ".html")

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

    def end_headers(self):
        # 跨源隔离（Godot Web 需要）
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # 禁止缓存，避免浏览器拿到旧构建
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"Cozy Shop 已启动：http://0.0.0.0:{PORT}/  (Ctrl+C 停止)")
        httpd.serve_forever()
