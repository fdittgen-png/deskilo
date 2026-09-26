// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/schema_version.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/identity_binding.dart';

/// #1647 — the three own-identity RPCs. A server without them (older
/// than 0269) answers `unavailable`, never `unlinked`.
class SupabaseIdentityBindingRepository implements IdentityBindingRepository {
  const SupabaseIdentityBindingRepository(this._client);

  final SupabaseClient _client;

  Future<IdentityBindingStatus> _call(String fn) async {
    try {
      return IdentityBindingStatus.fromJson(await _client.rpc<Object?>(fn));
    } on PostgrestException catch (e, st) {
      if (isMissingFunction(e)) {
        TraceLogger.instance.warn('identity', '$fn is absent on this server',
            error: e, stackTrace: st);
        return const IdentityBindingStatus(
          state: IdentityBindingState.unavailable,
          reason: 'server_predates_bindings',
        );
      }
      rethrow;
    }
  }

  @override
  Future<IdentityBindingStatus> status() => _call('my_identity_status');

  @override
  Future<IdentityBindingStatus> finalize() => _call('finalize_identity_binding');

  @override
  Future<IdentityBindingStatus> revoke() => _call('revoke_my_identity_binding');
}
