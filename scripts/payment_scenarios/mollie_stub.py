# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1639 — the local Mollie protocol boundary: a stateful stand-in for
# api.mollie.com on 127.0.0.1 answering the two endpoints the shipped
# adapter uses, POST /v2/payments and GET /v2/payments/{id}. It records
# every payment the real order handler creates — amount, method, metadata,
# the webhookUrl it was told to call, and the MODE the key implies
# (`test_…` → test) — and only answers a payment to the key that created
# it, as Mollie does: another workspace's key sees a 404. The runner moves
# a payment's status, or corrupts what the provider reports, through
# /_test/* endpoints. Every request is appended to the hits file.
import http.server
import json
import sys
import threading

payments = {}
faults = {'outage': False}
lock = threading.Lock()
hits = sys.argv[2]
prefix = sys.argv[3]


def key_of(headers):
    return (headers.get('Authorization') or '').replace('Bearer ', '')


class Mollie(http.server.BaseHTTPRequestHandler):
    def _log(self):
        with open(hits, 'a') as f:
            f.write(f'{self.command} {self.path}\n')

    def _json(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/hal+json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        raw = self.rfile.read(int(self.headers.get('Content-Length') or 0))
        try:
            return json.loads(raw or b'{}')
        except ValueError:
            return {}

    def _public(self, p):
        return {k: v for k, v in p.items() if k != '_key'}

    def do_POST(self):
        self._log()
        body = self._body()
        if self.path == '/v2/payments':
            key = key_of(self.headers)
            with lock:
                pid = f'tr_{prefix}_{len(payments) + 1}'
                payments[pid] = {
                    'resource': 'payment', 'id': pid, 'status': 'open',
                    'mode': 'test' if key.startswith('test_') else 'live',
                    'amount': body.get('amount'), 'description': body.get('description'),
                    'method': body.get('method'), 'metadata': body.get('metadata'),
                    'webhookUrl': body.get('webhookUrl'), 'redirectUrl': body.get('redirectUrl'),
                    '_links': {'checkout': {'href': f'https://www.mollie.test/checkout/{pid}'}},
                    '_key': key,
                }
            return self._json(201, self._public(payments[pid]))
        if self.path.startswith('/_test/'):
            parts = self.path.split('/')
            with lock:
                if parts[2] == 'outage':
                    faults['outage'] = bool(body.get('on'))
                    return self._json(200, faults)
                p = payments.get(parts[3] if len(parts) > 3 else '')
                if p is None:
                    return self._json(404, {})
                # /_test/set/<id> with any of status, method, mode, amount, metadata
                for k in ('status', 'method', 'mode', 'amount', 'metadata'):
                    if k in body:
                        p[k] = body[k]
                return self._json(200, self._public(p))
        self._json(404, {'status': 404, 'title': 'Not Found'})

    def do_GET(self):
        self._log()
        parts = self.path.split('/')
        if self.path.startswith('/v2/payments/') and len(parts) == 4:
            if faults['outage']:
                return self._json(503, {'status': 503, 'title': 'Service Unavailable'})
            p = payments.get(parts[3])
            if p is None or p['_key'] != key_of(self.headers):
                return self._json(404, {'status': 404, 'title': 'Not Found',
                                        'detail': 'No payment exists with token ' + parts[3]})
            return self._json(200, self._public(p))
        if self.path.startswith('/_test/payments/') and len(parts) == 4:
            p = payments.get(parts[3])
            return self._json(200 if p else 404, self._public(p) if p else {})
        self._json(404, {'status': 404, 'title': 'Not Found'})

    def log_message(self, *a):
        pass


http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), Mollie).serve_forever()
