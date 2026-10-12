// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_money_repository.dart';

// #2386 — part 4 of SupabaseMoneyRepository, split out of supabase_money_repository.dart so no
// file holds the whole class.
extension _SupabaseMoneyRepositoryPart4 on SupabaseMoneyRepository {

  Future<PaymentOrderStart> _createPaymentOrderImpl({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  }) async {
    final data = await _invokePayments({
      'provider': provider.wireName,
      'workspace_id': workspaceId,
      'member_id': memberId,
      'amount_cents': amountCents,
      'currency': currencyCode,
      'period': period,
      'request_id': ?requestId,
    });
    if (data == null) {
      return const PaymentOrderStart(
        missing: ['create-payment-order (not deployed)'],
      );
    }
    if (data['status'] == 'not_configured') {
      return PaymentOrderStart(
        missing: [
          for (final v in (data['missing'] as List? ?? const [])) v as String,
        ],
      );
    }
    if (data['status'] == 'paid') {
      return PaymentOrderStart(
        alreadyPaid: true,
        orderId: data['order_id'] as String?,
      );
    }
    final approveUrl = data['approve_url'];
    if (approveUrl is! String || approveUrl.isEmpty) {
      throw PaymentGatewayException(500, 'no approve_url in $data');
    }
    return PaymentOrderStart(
      approveUrl: Uri.parse(approveUrl),
      orderId: data['order_id'] as String?,
    );
  }

  Future<Map<PaymentProvider, PaymentProviderStatus>>
      _fetchPaymentGatewayStatusImpl(String workspaceId) async {
    final result = await _client.rpc<dynamic>(
      'payment_credentials_status',
      params: {'p_workspace_id': workspaceId},
    ) as Map<String, dynamic>;
    final out = <PaymentProvider, PaymentProviderStatus>{};
    for (final entry in result.entries) {
      final provider = PaymentProvider.fromWire(entry.key);
      if (provider == null) continue;
      final v = entry.value as Map<String, dynamic>;
      out[provider] = PaymentProviderStatus(
        configured: v['configured'] as bool? ?? false,
        publicFields: {
          for (final e in (v['public'] as Map? ?? const {}).entries)
            e.key as String: e.value as String,
        },
        secretKeysSet: {
          for (final k in (v['secret_keys'] as List? ?? const [])) k as String,
        },
      );
    }
    return out;
  }

  Future<void> _setPaymentCredentialsImpl(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    await _client.rpc<dynamic>('set_payment_credentials', params: {
      'p_workspace_id': workspaceId,
      'p_provider': provider.wireName,
      'p_config': config,
    });
  }

  Future<void> _clearPaymentProviderImpl(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    await _client.rpc<dynamic>('clear_payment_provider', params: {
      'p_workspace_id': workspaceId,
      'p_provider': provider.wireName,
    });
  }
}
