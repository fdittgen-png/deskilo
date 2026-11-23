// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — the active kinds of public.business_kinds, readable by everyone
// signed in (0703).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/schema_version.dart' show isMissingFunction;
import '../../../core/codes/pg_code.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/business_kind.dart';

class SupabaseBusinessKindRepository implements BusinessKindRepository {
  const SupabaseBusinessKindRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BusinessKind>> kinds() async {
    try {
      final rows = await _client
          .from('business_kinds')
          .select('code, sort_order, feature_profile, profile_version, profile_digest')
          .eq('active', true)
          .order('sort_order');
      return [for (final r in rows) BusinessKind.fromJson(r)];
    } on PostgrestException catch (e, st) {
      // 42703: a server from before 0834 has no profile version or digest: read
      // the kinds as it has them, every profile at the first version.
      if (e.code != PgCode.undefinedColumn) rethrow;
      TraceLogger.instance.warn(
        'workspace',
        'the server keeps no profile version for its business kinds',
        error: e,
        stackTrace: st,
      );
      final rows = await _client
          .from('business_kinds')
          .select('code, sort_order, feature_profile')
          .eq('active', true)
          .order('sort_order');
      return [for (final r in rows) BusinessKind.fromJson(r)];
    }
  }

  @override
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  }) => _client.rpc<Object?>(
    'set_business_kind',
    params: {
      'p_workspace': workspaceId,
      'p_kind': kind,
      'p_more_kinds': moreKinds.join(','),
    },
  );

  @override
  Future<BusinessKindApplied> applyKind(
    String workspaceId, {
    required String requestId,
    required ReviewedKind reviewed,
    required Map<String, bool> flags,
    required Map<String, bool> expected,
  }) async {
    try {
      final answer = await _client.rpc<Object?>(
        'apply_business_kind_v1',
        params: {
          'p_workspace': workspaceId,
          'p_request_id': requestId,
          'p_kind': reviewed.kind,
          'p_more_kinds': reviewed.moreKinds.join(','),
          'p_reviewed_version': reviewed.version,
          'p_reviewed_digest': reviewed.digest,
          'p_flags': flags,
          'p_expected': expected.isEmpty ? null : expected,
        },
      );
      final r = JsonReader.of(answer, context: 'apply_business_kind_v1');
      return BusinessKindApplied(
        kindStage: r.string('kind_stage'),
        flagsStage: r.string('flags_stage'),
        refusal: r.stringOrNull('refusal') ?? '',
      );
    } on PostgrestException catch (e, st) {
      if (isMissingFunction(e)) {
        Error.throwWithStackTrace(const BusinessKindApplyUnsupported(), st);
      }
      rethrow;
    }
  }
}
