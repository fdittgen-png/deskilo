// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the billing-access grants over the RPCs of 0910. A server refusal
// becomes a typed [BillingAccessRefusal]; a transport failure passes through
// untouched (a write is never retried here: the screen offers the retry, and a
// request id makes the retry of an invitation the same invitation).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/paged_fetch.dart';
import '../domain/billing_access.dart';

class SupabaseBillingAccessRepository implements BillingAccessRepository {
  const SupabaseBillingAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BillingAccessGrant>> grantsOf(
    String workspaceId,
    String subjectId,
  ) async {
    final rows = await _asRefusal(
      () => fetchConfigurationList(
        table: 'billing_access_grants',
        build: () => _client
            .from('billing_access_grants')
            .select(
              'id, financial_subject_id, invited_at, expires_at, accepted_at, '
              'revoked_at, revoke_reason',
            )
            .eq('workspace_id', workspaceId)
            .eq('financial_subject_id', subjectId)
            .order('invited_at', ascending: false)
            .order('id'),
      ),
    );
    return [for (final row in rows) BillingAccessGrant.fromJson(row)];
  }

  /// The financial subjects this account holds a live grant for, whichever
  /// business issued it: the account's own rows, across every seller by
  /// design (the account is the principal; the seller's rows are not its).
  Future<Set<String>> heldSubjects() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const {};
    final rows = await fetchConfigurationList(table: 'billing_access_grants', build: () => _client
        .from('billing_access_grants')
        .select('financial_subject_id')
        .eq('principal_user_id', me)
        .filter('revoked_at', 'is', null)
        .order('id'));
    return {for (final r in rows) r['financial_subject_id'] as String};
  }

  @override
  Future<BillingAccessInvitation> invite(
    String workspaceId,
    String subjectId,
    String requestId,
  ) async => BillingAccessInvitation.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'billing_access_invite_v1',
        params: {
          'p_workspace': workspaceId,
          'p_subject': subjectId,
          'p_request_id': requestId,
        },
      ),
    ),
  );

  @override
  Future<BillingAccessPreview> preview(String code) async =>
      BillingAccessPreview.fromJson(
        await _asRefusal(
          () => _client.rpc<Object?>(
            'billing_access_preview_v1',
            params: {'p_code': code},
          ),
        ),
      );

  @override
  Future<BillingAccessAccepted> accept(String code) async =>
      BillingAccessAccepted.fromJson(
        await _asRefusal(
          () => _client.rpc<Object?>(
            'billing_access_accept_v1',
            params: {'p_code': code},
          ),
        ),
      );

  @override
  Future<void> revoke(String grantId, {String reason = ''}) async {
    await _asRefusal(
      () => _client.rpc<Object?>(
        'billing_access_revoke_v1',
        params: {'p_grant_id': grantId, 'p_reason': reason},
      ),
    );
  }

  /// The refusals of 0910 by code: the seller's right DKN01 (an assistant DKU02),
  /// the unusable code DKH01, the subject that is no customer DKH02, the unknown
  /// grant DKH03, the long reason DKH04 and the reused request id DKH05.
  Future<T> _asRefusal<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e, st) {
      // trace-exempt: a refusal is rethrown typed with its cause and stack; a
      // failure that is not one passes through untouched.
      final kind = switch (e.code) {
        DkCode.dkn01 || DkCode.dku02 => BillingAccessRefusalKind.notAllowed,
        DkCode.dkh01 => BillingAccessRefusalKind.codeUnusable,
        DkCode.dkh02 => BillingAccessRefusalKind.notACustomer,
        DkCode.dkh03 => BillingAccessRefusalKind.unknownGrant,
        DkCode.dkh04 => BillingAccessRefusalKind.reasonTooLong,
        DkCode.dkh05 => BillingAccessRefusalKind.requestReused,
        _ => null,
      };
      if (kind == null) rethrow;
      Error.throwWithStackTrace(BillingAccessRefusal(kind, cause: e), st);
    }
  }
}
