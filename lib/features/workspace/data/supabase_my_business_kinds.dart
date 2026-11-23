// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- `my_business_kinds_v1` (0845). A server from before it answers with
// an unknown function: that is "no kinds known", not a failure of the page that
// names the businesses.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/pg_code.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/my_business_kinds.dart';

class SupabaseMyBusinessKinds implements MyBusinessKindsReader {
  const SupabaseMyBusinessKinds(this._client);

  final SupabaseClient _client;

  /// PostgREST's answers for a function the server does not have.
  static const _unknownFunction = {PgCode.pgrstFunctionNotFound, PgCode.undefinedFunction};

  @override
  Future<Map<String, String>> read() async {
    try {
      final rows = await _client.rpc<Object?>('my_business_kinds_v1');
      if (rows is! List) return const {};
      final out = <String, String>{};
      for (final row in rows) {
        final r = JsonReader.of(row, context: 'my_business_kinds_v1');
        final kind = r.stringOr('kind');
        if (kind.isNotEmpty) out[r.string('workspace_id')] = kind;
      }
      return out;
    } on PostgrestException catch (e, st) {
      if (!_unknownFunction.contains(e.code)) rethrow;
      TraceLogger.instance.warn(
        'workspace',
        'the server does not name the kinds of my businesses',
        error: e,
        stackTrace: st,
      );
      return const {};
    }
  }
}
