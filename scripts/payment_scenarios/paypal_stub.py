# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1638 — the local PayPal protocol boundary: a stateful stand-in for
# api-m.sandbox.paypal.com on 127.0.0.1, answering exactly the endpoints
# the shipped adapter calls — the OAuth token, Orders v2 create / detail /
# capture, and webhook-signature verification. It remembers every order
# the real order handler opens and captures ONCE per order: a capture
# request carrying a PayPal-Request-Id it has seen returns the first
# answer (PayPal's documented idempotency), any other capture of a
# captured order is 422 ORDER_ALREADY_CAPTURED, and an order the buyer
# has not approved is 422 ORDER_NOT_APPROVED.
#
# Verification answers SUCCESS only for the transmission signature
# `sig-ok`: this is LOCAL PROTOCOL evidence, never proof of PayPal's live
# signatures. The scenario runner drives the buyer and the faults through
# /_test/* endpoints. Every request is appended to the hits file.
import http.server
import json
import sys
import threading

orders = {}
by_request_id = {}
faults = {'verify_outage': False, 'drop_capture_reply': set()}
lock = threading.Lock()
hits = sys.argv[2]
prefix = sys.argv[3]


def capture_body(order):
    return {
        'id': order['id'],
        'status': 'COMPLETED',
        'purchase_units': [{
            'custom_id': order['custom_id'],
            'amount': order['amount'],
            'payments': {'captures': [{
                'id': order['capture_id'],
                'status': 'COMPLETED',
                'amount': order['amount'],
            }]},
        }],
    }


class PayPal(http.server.BaseHTTPRequestHandler):
    def _log(self):
        with open(hits, 'a') as f:
            f.write(f'{self.command} {self.path}\n')

    def _json(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        raw = self.rfile.read(int(self.headers.get('Content-Length') or 0))
        try:
            return json.loads(raw or b'{}')
        except ValueError:
            return {}

    def do_POST(self):
        self._log()
        path = self.path
        if path == '/v1/oauth2/token':
            self._body()
            return self._json(200, {'access_token': 'A21_local', 'token_type': 'Bearer'})
        if path == '/v1/notifications/verify-webhook-signature':
            body = self._body()
            if faults['verify_outage']:
                return self._json(503, {'name': 'SERVICE_UNAVAILABLE'})
            ok = body.get('transmission_sig') == 'sig-ok' and body.get('webhook_id')
            return self._json(200, {'verification_status': 'SUCCESS' if ok else 'FAILURE'})
        if path == '/v2/checkout/orders':
            body = self._body()
            unit = (body.get('purchase_units') or [{}])[0]
            with lock:
                oid = f'{prefix}-{len(orders) + 1}'
                orders[oid] = {
                    'id': oid, 'status': 'CREATED', 'intent': body.get('intent'),
                    'amount': unit.get('amount'), 'custom_id': unit.get('custom_id'),
                    'capture_id': f'CAP-{oid}', 'captures': 0,
                }
            return self._json(201, {'id': oid, 'status': 'CREATED', 'links': [
                {'rel': 'approve', 'href': f'https://www.sandbox.paypal.test/checkoutnow?token={oid}'}]})
        if path.startswith('/v2/checkout/orders/') and path.endswith('/capture'):
            self._body()
            oid = path.split('/')[4]
            rid = self.headers.get('PayPal-Request-Id')
            with lock:
                order = orders.get(oid)
                if order is None:
                    return self._json(404, {'name': 'RESOURCE_NOT_FOUND'})
                if rid and rid in by_request_id:
                    return self._json(201, by_request_id[rid])
                if order['status'] == 'COMPLETED':
                    return self._json(422, {'name': 'UNPROCESSABLE_ENTITY',
                                            'details': [{'issue': 'ORDER_ALREADY_CAPTURED'}]})
                if order['status'] != 'APPROVED':
                    return self._json(422, {'name': 'UNPROCESSABLE_ENTITY',
                                            'details': [{'issue': 'ORDER_NOT_APPROVED'}]})
                order['status'] = 'COMPLETED'
                order['captures'] += 1
                body = capture_body(order)
                if rid:
                    by_request_id[rid] = body
                drop = oid in faults['drop_capture_reply']
                faults['drop_capture_reply'].discard(oid)
            if drop:
                # The capture happened; the reply is lost on the way back.
                return self._json(502, {'name': 'BAD_GATEWAY'})
            return self._json(201, body)
        # ── test controls ────────────────────────────────────────────
        if path.startswith('/_test/'):
            parts = path.split('/')
            body = self._body()
            with lock:
                if parts[2] == 'verify-outage':
                    faults['verify_outage'] = bool(body.get('on'))
                    return self._json(200, faults | {'drop_capture_reply': []})
                oid = parts[3] if len(parts) > 3 else ''
                order = orders.get(oid)
                if order is None:
                    return self._json(404, {})
                if parts[2] == 'approve':
                    order['status'] = 'APPROVED'
                elif parts[2] == 'void':
                    order['status'] = 'VOIDED'
                elif parts[2] == 'capture-elsewhere':
                    order['status'] = 'COMPLETED'
                    order['captures'] += 1
                elif parts[2] == 'drop-capture-reply':
                    faults['drop_capture_reply'].add(oid)
                return self._json(200, order)
        self._json(404, {'name': 'RESOURCE_NOT_FOUND'})

    def do_GET(self):
        self._log()
        parts = self.path.split('/')
        if self.path.startswith('/v2/checkout/orders/') and len(parts) == 5:
            order = orders.get(parts[4])
            if order is None:
                return self._json(404, {'name': 'RESOURCE_NOT_FOUND'})
            if order['status'] == 'COMPLETED':
                return self._json(200, capture_body(order))
            return self._json(200, {'id': order['id'], 'status': order['status'],
                                    'purchase_units': [{'custom_id': order['custom_id'],
                                                        'amount': order['amount']}]})
        if self.path.startswith('/_test/orders/') and len(parts) == 4:
            order = orders.get(parts[3])
            return self._json(200 if order else 404, order or {})
        self._json(404, {'name': 'RESOURCE_NOT_FOUND'})

    def log_message(self, *a):
        pass


http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), PayPal).serve_forever()
