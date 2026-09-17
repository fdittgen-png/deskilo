// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/credit_product.dart';

/// #1279 — carnets over Supabase (0236, 0238).
class SupabaseCreditRepository implements CreditRepository {
  SupabaseCreditRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CreditProduct>> fetchCreditProducts(String workspaceId) async {
    final rows = await _client
        .from('credit_products')
        .select()
        .eq('workspace_id', workspaceId)
        .order('sort_order')
        .order('name');
    return [
      for (final row in rows)
        CreditProduct.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> createCreditProduct(
    String workspaceId, {
    required String name,
    required int halfDays,
    required int priceCents,
    int? validityMonths,
  }) =>
      _client.from('credit_products').insert({
        'workspace_id': workspaceId,
        'name': name,
        'half_days': halfDays,
        'price_cents': priceCents,
        'validity_months': validityMonths,
      });

  @override
  Future<void> setCreditProductActive(String productId, bool active) => _client
      .from('credit_products')
      .update({'active': active}).eq('id', productId);

  @override
  Future<String> sellCredit(
      String workspaceId, String memberId, String productId) async {
    final id = await _client.rpc<dynamic>('sell_credit', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_product_id': productId,
    });
    return id as String;
  }

  @override
  Future<int> memberCreditBalance(String memberId) async {
    final value = await _client.rpc<dynamic>('member_credit_balance',
        params: {'p_member_id': memberId});
    return (value as num?)?.toInt() ?? 0;
  }
}
