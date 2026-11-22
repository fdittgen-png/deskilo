// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4324 — a send the server answers `binding_changed` (409: the invoice already
// has a submission to this destination with other content) reaches the app as
// a conflict of its own, whatever phase the first submission is in: the
// screen says so in its own sentence, never "accepted" for a document that
// was not sent again.
import 'dart:convert';

import 'package:deskilo/features/money/data/supabase_einvoice_transmissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _answering(int status, Object body) => SupabaseClient(
  'http://localhost',
  'anon-key',
  httpClient: MockClient(
    (request) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    ),
  ),
);

Future<bool> _conflictOf(int status, Object body) async {
  final submission = await SupabaseEInvoiceTransmissions(
    _answering(status, body),
  ).sendEInvoice(
    workspaceId: 'ws-1',
    invoiceId: 'inv-1',
    fileName: 'f.pdf',
    mimeType: 'application/pdf',
    bytes: const [1],
    format: 'facturX',
  );
  return submission.conflict;
}

void main() {
  test('a 409 binding_changed is a conflict, for every phase', () async {
    for (final phase in ['sent', 'uncertain', 'accepted', 'rejected']) {
      expect(
        await _conflictOf(409, {
          'error': 'binding_changed',
          'phase': phase,
          'transmission_id': 't-1',
        }),
        isTrue,
        reason: phase,
      );
    }
  });

  test('an answer that is not that conflict is not one', () async {
    expect(await _conflictOf(200, {'status': 'accepted', 'phase': 'accepted'}), isFalse);
    expect(await _conflictOf(409, {'error': 'not_connected'}), isFalse);
  });
}
