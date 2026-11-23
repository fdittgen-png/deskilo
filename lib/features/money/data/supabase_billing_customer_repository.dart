// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the billing customers over the RPCs of 0821. A server refusal
// becomes a typed [BillingCustomerRefusal]; a transport failure passes through
// untouched (a write is never retried here: the editor offers the retry).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/dk_code.dart';
import '../domain/billing_customer.dart';

class SupabaseBillingCustomerRepository implements BillingCustomerRepository {
  const SupabaseBillingCustomerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BillingParty>> fetch(String workspaceId) async {
    final rows = await _asRefusal(
      () => _client.rpc<Object?>(
        'billing_customers_v1',
        params: {'p_workspace': workspaceId},
      ),
    );
    if (rows is! List) return const [];
    return [for (final row in rows) BillingParty.fromJson(row)];
  }

  @override
  Future<String> create(
    String workspaceId,
    BillingPartyDraft draft, {
    String? capacity,
  }) async {
    final id = await _asRefusal(
      () => _client.rpc<Object?>(
        'billing_customer_create_v1',
        params: {
          'p_workspace': workspaceId,
          'p_party': draft.toWire(),
          'p_capacity': ?capacity,
        },
      ),
    );
    return id as String;
  }

  @override
  Future<BillingParty> save(
    String workspaceId,
    String subjectId,
    BillingPartyDraft draft, {
    required int expectedRevision,
    String? capacity,
  }) async {
    final row = await _asRefusal(
      () => _client.rpc<Object?>(
        'billing_party_save_v1',
        params: {
          'p_workspace': workspaceId,
          'p_subject': subjectId,
          'p_party': draft.toWire(),
          'p_expected_revision': expectedRevision,
          'p_capacity': ?capacity,
        },
      ),
    );
    return BillingParty.fromJson(row);
  }

  /// The server's refusals of 0821, by code: the permission refusal DKN01, the
  /// assistant's DKU02, the name DKU03, the unknown subject DKU04 and the stale
  /// revision DKU05.
  Future<T> _asRefusal<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e, st) {
      // trace-exempt: a refusal is rethrown typed with its cause and stack; a
      // failure that is not one passes through untouched.
      final kind = switch (e.code) {
        DkCode.dkn01 || DkCode.dku02 => BillingCustomerRefusalKind.notAllowed,
        DkCode.dku05 => BillingCustomerRefusalKind.stale,
        DkCode.dku04 => BillingCustomerRefusalKind.unknownCustomer,
        DkCode.dku03 => BillingCustomerRefusalKind.nameNeeded,
        _ => null,
      };
      if (kind == null) rethrow;
      Error.throwWithStackTrace(BillingCustomerRefusal(kind, cause: e), st);
    }
  }
}
