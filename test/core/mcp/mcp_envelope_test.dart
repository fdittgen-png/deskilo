// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1801 — the envelopes the API reference documents parse through the
// app's own reader: pending is never completed, and an unknown version or
// status is refused.
import 'package:deskilo/core/mcp/mcp_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mcp_contract/render.dart';

void main() {
  test('every documented envelope parses, and says what it is', () {
    final byStatus = {
      for (final e in mcpDocumentedEnvelopes)
        e['status']: McpEnvelopeView.parse(e),
    };
    expect(byStatus['completed']!.completed, isTrue);
    expect(byStatus['pending_validation']!.completed, isFalse);
    expect(byStatus['pending_validation']!.pendingValidation, isTrue);
    expect(byStatus['pending_validation']!.eventId, isNotNull);
    expect(byStatus['requires_confirmation']!.needsConfirmation, isTrue);
    expect(byStatus['denied']!.errorCode, 'not_eligible');
  });

  test('an unknown version or status is refused, not guessed', () {
    final ok = mcpDocumentedEnvelopes.first;
    expect(
      () => McpEnvelopeView.parse({...ok, 'schema_version': 2}),
      throwsFormatException,
    );
    expect(
      () => McpEnvelopeView.parse({...ok, 'status': 'done'}),
      throwsFormatException,
    );
    expect(
      () => McpEnvelopeView.parse({...ok}..remove('request_id')),
      throwsFormatException,
    );
  });
}
