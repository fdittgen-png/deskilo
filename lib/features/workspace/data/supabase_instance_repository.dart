// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/schema_version.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/instance_responsibles.dart';

/// #1829 — the instance owner and their delegates (0314). A server older
/// than 0314 answers "nobody is named" and refuses every change, never an
/// error the screen would have to explain.
class SupabaseInstanceRepository implements InstanceRepository {
  const SupabaseInstanceRepository(this._client);

  final SupabaseClient _client;

  Future<T> _call<T>(
    String fn,
    T Function(Object? json) parse,
    T missing, {
    Map<String, Object?>? params,
  }) async {
    try {
      return parse(await _client.rpc<Object?>(fn, params: params));
    } on PostgrestException catch (e, st) {
      if (isMissingFunction(e)) {
        TraceLogger.instance.warn(
          'instance',
          '$fn is absent on this server',
          error: e,
          stackTrace: st,
        );
        return missing;
      }
      rethrow;
    }
  }

  @override
  Future<InstanceResponsibles> responsibles() => _call(
    'instance_responsibles',
    InstanceResponsibles.fromJson,
    InstanceResponsibles.unavailable,
  );

  @override
  Future<DelegationOutcome> delegate(String email) => _call(
    'delegate_instance_role',
    DelegationOutcome.fromJson,
    DelegationOutcome.unavailable,
    params: {'p_email': email.trim()},
  );

  @override
  Future<bool> withdraw(String userId) => _call(
    'withdraw_instance_delegation',
    (j) => j is Map && j['status'] == 'withdrawn',
    false,
    params: {'p_user': userId},
  );

  @override
  Future<bool> claim() => _call(
    'claim_instance_ownership',
    (j) => j is Map && j['status'] == 'claimed',
    false,
  );
}
