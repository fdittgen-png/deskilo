# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1637 — the local Stripe protocol boundary. A stateful stand-in for
# api.stripe.com on 127.0.0.1 that REMEMBERS every Checkout Session the
# real order handler opens (amount, currency, client reference) and
# answers the session-detail read the scenario runner makes before it
# signs an event — so an event's amount and reference come from what the
# provider recorded, never from the scenario's own copy of them. Every
# request is appended to the hits file as `METHOD PATH`. No key is real
# and no request leaves the runner. Q-018 / Q-019 add a sibling per
# provider; nothing here answers for another one.
import http.server
import json
import sys
import urllib.parse

sessions = {}
hits = sys.argv[2]


class Stripe(http.server.BaseHTTPRequestHandler):
    def _log(self):
        with open(hits, 'a') as f:
            f.write(f'{self.command} {self.path}\n')

    def _json(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        self._log()
        raw = self.rfile.read(int(self.headers.get('Content-Length') or 0))
        if self.path != '/v1/checkout/sessions':
            return self._json(404, {'error': {'message': 'unknown endpoint'}})
        form = dict(urllib.parse.parse_qsl(raw.decode()))
        sid = f'cs_test_stub_{len(sessions) + 1}'
        sessions[sid] = {
            'id': sid,
            'object': 'checkout.session',
            'client_reference_id': form.get('client_reference_id'),
            'amount_total': int(form.get('line_items[0][price_data][unit_amount]', '0')),
            'currency': form.get('line_items[0][price_data][currency]'),
            'payment_intent': f'pi_{sid}',
            'payment_status': 'unpaid',
            'status': 'open',
            'url': f'https://checkout.example.test/{sid}',
        }
        self._json(200, sessions[sid])

    def do_GET(self):
        self._log()
        sid = self.path.rsplit('/', 1)[-1]
        if self.path.startswith('/v1/checkout/sessions/') and sid in sessions:
            return self._json(200, sessions[sid])
        self._json(404, {'error': {'message': f'No such checkout.session: {sid}'}})

    def log_message(self, *a):
        pass


http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), Stripe).serve_forever()
