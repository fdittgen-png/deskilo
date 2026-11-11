// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 -- match_invoice sends a part only when one is given. An
// installation that has not received 0717 has no fifth parameter: a call
// carrying `p_amount_cents: null` would find no function there, and every
// match on that installation would fail.
import 'dart:convert';

import 'package:deskilo/features/money/data/supabase_invoice_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>> _sent(int? amountCents) async {
  final bodies = <Map<String, dynamic>>[];
  final client = SupabaseClient(
    'https://match.example',
    'sb_publishable_match',
    httpClient: MockClient((request) async {
      if (request.url.path == '/rest/v1/rpc/match_invoice') {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response('', 204, request: request);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await SupabaseInvoiceCommands(client).matchInvoice(
    invoiceId: 'inv-1',
    paymentLedgerId: 'pay-1',
    resolution: 'exact',
    amountCents: amountCents,
  );
  expect(bodies, hasLength(1));
  return bodies.single;
}

void main() {
  test('without a part, the call has the four arguments every '
      'installation knows', () async {
    final sent = await _sent(null);
    expect(sent.keys.toSet(), {
      'p_invoice_id',
      'p_payment_ledger_id',
      'p_resolution',
      'p_note',
    });
  });

  test('with a part, the call carries it as p_amount_cents', () async {
    final sent = await _sent(12000);
    expect(sent['p_amount_cents'], 12000);
  });
}
