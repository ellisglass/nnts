#!/usr/bin/env python3
"""
Simple HTTP server with Range-Header support for fluid MP4 video seeking and streaming.
Usage: python3 serve.py [port]
"""

import os
import sys
import mimetypes
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent

class RangeRequestHandler(BaseHTTPRequestHandler):
    def translate_path(self, path):
        # Strip query parameters
        clean_path = path.split('?', 1)[0].split('#', 1)[0]
        rel_path = clean_path.lstrip('/')
        if not rel_path:
            rel_path = 'index.html'
        full_path = (DIRECTORY / rel_path).resolve()
        if full_path.is_dir():
            full_path = (full_path / 'index.html').resolve()
        # Security check: must stay within DIRECTORY
        if not str(full_path).startswith(str(DIRECTORY)):
            return None
        return full_path

    def do_HEAD(self):
        self.send_file(send_body=False)

    def do_GET(self):
        self.send_file(send_body=True)

    def send_file(self, send_body=True):
        file_path = self.translate_path(self.path)
        if file_path is None or not file_path.exists() or file_path.is_dir():
            self.send_error(404, "File not found")
            return

        ctype, _ = mimetypes.guess_type(str(file_path))
        if ctype is None:
            ctype = 'application/octet-stream'

        file_size = file_path.stat().st_size
        range_header = self.headers.get('Range')

        if range_header and range_header.startswith('bytes='):
            # Parse Range: bytes=start-end
            try:
                ranges = range_header.split('=', 1)[1].split('-')
                start = int(ranges[0]) if ranges[0] else 0
                end = int(ranges[1]) if ranges[1] else file_size - 1
                if start >= file_size or end >= file_size or start > end:
                    self.send_error(416, "Requested Range Not Satisfiable")
                    return
                length = end - start + 1

                self.send_response(206)
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Range', f'bytes {start}-{end}/{file_size}')
                self.send_header('Content-Length', str(length))
                self.send_header('Accept-Ranges', 'bytes')
                self.send_header('Cache-Control', 'no-cache')
                self.end_headers()

                if send_body:
                    with open(file_path, 'rb') as f:
                        f.seek(start)
                        remaining = length
                        while remaining > 0:
                            chunk_size = min(remaining, 64 * 1024)
                            chunk = f.read(chunk_size)
                            if not chunk:
                                break
                            self.wfile.write(chunk)
                            remaining -= len(chunk)
                return
            except Exception as e:
                pass

        # Standard 200 OK
        self.send_response(200)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(file_size))
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()

        if send_body:
            with open(file_path, 'rb') as f:
                while True:
                    chunk = f.read(64 * 1024)
                    if not chunk:
                        break
                    self.wfile.write(chunk)

def run(port=8080):
    server_address = ('127.0.0.1', port)
    httpd = HTTPServer(server_address, RangeRequestHandler)
    print(f"🐹 Xomsky Web Server running at: http://127.0.0.1:{port}/")
    print(f"📂 Serving directory: {DIRECTORY}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run(port)
