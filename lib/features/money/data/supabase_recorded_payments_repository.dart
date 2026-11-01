// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/recorded_payments.dart';

/// #2578 — `workspace_recorded_payments_v1` (0643).
class SupabaseRecordedPaymentsRepository implements RecordedPaymentsRepository {
  const SupabaseRecordedPaymentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RecordedPaymentsPage> page(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    RecordedPaymentsCursor? after,
    int? limit,
  }) async {
    final Object? body;
    try {
      body = await _client.rpc<Object?>(
        'workspace_recorded_payments_v1',
        params: recordedPaymentsParams(
          workspaceId,
          from: from,
          to: to,
          after: after,
          limit: limit,
        ),
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the list shows it.
      switch (e.code) {
        case '42501':
          Error.throwWithStackTrace(const RecordedPaymentsForbidden(), st);
        case '55000':
          Error.throwWithStackTrace(const RecordedPaymentsSwitchedOff(), st);
      }
      rethrow;
    }
    return RecordedPaymentsPage.fromJson(body);
  }
}
