// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1801 — the envelopes the API reference documents parse through the
// app's own reader: pending is never completed, and an unknown version or
// status is refused.
import 'package:deskilo/core/mcp/mcp_operations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mcp_contract/render.dart';

void main() {
  test('every documented envelope parses, and says what it is', () {
    final byStatus = {
      for (final e in mcpDocumentedEnvelopes)
        e['status']: McpEnvelope.parse(e),
    };
    expect(byStatus['completed']!.completed, isTrue);
    expect(byStatus['pending_validation']!.completed, isFalse);
    expect(byStatus['pending_validation']!.pendingValidation, isTrue);
    expect(byStatus['pending_validation']!.eventId, isNotNull);
    expect(byStatus['requires_confirmation']!.needsConfirmation, isTrue);
    expect(byStatus['denied']!.errorCode, 'not_eligible');
    expect(byStatus['completed']!.operation, McpOperationId.requestSubscriptionChange);
  });

  test('#2394 a validation refusal names its fields; an unknown operation is refused', () {
    final ok = mcpDocumentedEnvelopes.first;
    final refused = McpEnvelope.parse({
      ...ok,
      'status': 'validation_error',
      'error': {
        'code': 'invalid_arguments',
        'fields': {'limit': 'invalid_integer'},
      },
    });
    expect(refused.errorFields, {'limit': 'invalid_integer'});
    expect(
      () => McpEnvelope.parse({...ok, 'operation': 'drop_everything'}),
      throwsFormatException,
    );
  });

  test('an unknown version or status is refused, not guessed', () {
    final ok = mcpDocumentedEnvelopes.first;
    expect(
      () => McpEnvelope.parse({...ok, 'schema_version': 2}),
      throwsFormatException,
    );
    expect(
      () => McpEnvelope.parse({...ok, 'status': 'done'}),
      throwsFormatException,
    );
    expect(
      () => McpEnvelope.parse({...ok}..remove('request_id')),
      throwsFormatException,
    );
  });
}
