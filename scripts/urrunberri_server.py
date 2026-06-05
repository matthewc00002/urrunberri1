#!/usr/bin/env python3
# =============================================================================
#  UrrunBerri OS — Python API Server
#  Port 7070 — localhost only
#  Author : Mathieu Cadi — Openema SARL
#  GitHub : https://github.com/matthewc00002/urrunberri1
# =============================================================================

import http.server
import urllib.parse
import json
import subprocess
import os

SAVED_FILE = "/etc/urrunberri-os/saved_connections.csv"
SPLASH_DIR = "/opt/urrunberri-os/splash"
ACTION_FILE = "/tmp/urrunberri_action.txt"
RESULT_FILE = "/tmp/urrunberri_login.txt"
PORT = 7070

def write_action(action, data=""):
    with open(ACTION_FILE, 'w') as f:
        f.write(action)
    if data:
        with open(RESULT_FILE, 'w') as f:
            f.write(data)

def load_connections():
    conns = []
    try:
        if os.path.exists(SAVED_FILE):
            with open(SAVED_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    parts = line.split('|')
                    while len(parts) < 8:
                        parts.append('')
                    conns.append({
                        'host':       parts[0],
                        'port':       parts[1],
                        'user':       parts[2],
                        'domain':     parts[3],
                        'name':       parts[4],
                        'protocol':   parts[5] or 'rdp',
                        'resolution': parts[6] or '1920x1080',
                        'multimon':   parts[7] or '0'
                    })
    except:
        pass
    return conns

def save_connection(host, port, user, domain='', name='', protocol='rdp', resolution='1920x1080', multimon='0'):
    if not host or not user:
        return load_connections()
    conns = [c for c in load_connections()
             if not (c['host'] == host and c['port'] == port and c['user'] == user)]
    conns.insert(0, {
        'host': host, 'port': port, 'user': user,
        'domain': domain, 'name': name, 'protocol': protocol or 'rdp',
        'resolution': resolution or '1920x1080', 'multimon': multimon or '0'
    })
    conns = conns[:10]
    with open(SAVED_FILE, 'w') as f:
        for c in conns:
            f.write(f"{c['host']}|{c['port']}|{c['user']}|{c['domain']}|{c['name']}|{c['protocol']}|{c['resolution']}|{c['multimon']}\n")
    return conns

def delete_connection(index):
    conns = load_connections()
    if 0 <= index < len(conns):
        conns.pop(index)
    with open(SAVED_FILE, 'w') as f:
        for c in conns:
            f.write(f"{c['host']}|{c['port']}|{c['user']}|{c['domain']}|{c['name']}|{c['protocol']}|{c['resolution']}|{c['multimon']}\n")
    return conns

def test_connection(host, port):
    try:
        r1 = subprocess.run(['ping', '-c1', '-W2', host], capture_output=True, timeout=5)
        r2 = subprocess.run(['nc', '-z', '-w3', host, str(port)], capture_output=True, timeout=5)
        return 'ok' if r1.returncode == 0 and r2.returncode == 0 else 'fail'
    except:
        return 'fail'

class UrrunBerriHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        pass

    def send_json(self, obj):
        body = json.dumps(obj).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()
        self.wfile.write(body)

    def send_cors(self, body='OK', content_type='text/plain'):
        encoded = body.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', len(encoded))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()
        self.wfile.write(encoded)

    def read_body(self):
        length = int(self.headers.get('Content-Length', 0))
        return self.rfile.read(length) if length else b''

    def do_OPTIONS(self):
        self.send_cors()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        body = self.read_body()

        try:
            data = json.loads(body)
        except:
            data = {}

        if path == '/save':
            conns = save_connection(
                host       = data.get('host', ''),
                port       = data.get('port', '3389'),
                user       = data.get('user', ''),
                domain     = data.get('domain', ''),
                name       = data.get('name', ''),
                protocol   = data.get('protocol', 'rdp'),
                resolution = data.get('resolution', '1920x1080'),
                multimon   = data.get('multimon', '0')
            )
            self.send_json({'ok': True, 'connections': conns})
            return

        if path == '/delete':
            index = data.get('index', -1)
            conns = delete_connection(int(index))
            self.send_json({'ok': True, 'connections': conns})
            return

        self.send_cors('ok')

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == '/splash/login.html':
            try:
                conns = load_connections()
                conns_json = json.dumps(conns)
                with open(f"{SPLASH_DIR}/login.html", 'r') as f:
                    html = f.read()
                html = html.replace('__SAVED_CONNECTIONS__', conns_json)
                encoded = html.encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', len(encoded))
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(encoded)
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
            return

        if path == '/splash/urrunberri.png':
            try:
                with open(f"{SPLASH_DIR}/urrunberri.png", 'rb') as f:
                    data = f.read()
                mime = 'image/jpeg' if data[:2] == b'\xff\xd8' else 'image/png'
                self.send_response(200)
                self.send_header('Content-Type', mime)
                self.send_header('Content-Length', len(data))
                self.end_headers()
                self.wfile.write(data)
            except:
                self.send_response(404)
                self.end_headers()
            return

        if path == '/test':
            host = params.get('host', [''])[0]
            port = params.get('port', ['3389'])[0]
            result = test_connection(host, port)
            self.send_cors(result)
            return

        if path == '/shutdown':
            self.send_cors('OK')
            write_action('shutdown')
            return

        if path == '/reboot':
            self.send_cors('OK')
            write_action('reboot')
            return

        if path == '/close':
            self.send_cors('OK')
            write_action('close')
            return

        if path == '/terminal':
            self.send_cors('OK')
            write_action('terminal')
            return

        if path == '/connect':
            data = params.get('data', [''])[0]
            write_action('connect', data)
            self.send_cors('connecting')
            return

        self.send_cors('ok')

def run():
    os.makedirs('/etc/urrunberri-os', exist_ok=True)
    if not os.path.exists(SAVED_FILE):
        open(SAVED_FILE, 'w').close()
    server = http.server.HTTPServer(('127.0.0.1', PORT), UrrunBerriHandler)
    print(f"[UrrunBerri OS] API server running on port {PORT}")
    server.serve_forever()

if __name__ == '__main__':
    run()
