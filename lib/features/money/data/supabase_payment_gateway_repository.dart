// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../domain/payment_gateway_repository.dart';
import '../domain/payment_intent.dart';
import '../domain/payment_provider.dart';
import '../domain/payment_test_check.dart';

/// #2591 — online payments and their provider credentials, with its own client.
/// The bodies are the ones that lived in the money repository and its part
/// files.
class SupabasePaymentGatewayRepository implements PaymentGatewayRepository {
  SupabasePaymentGatewayRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) async {
    // #1310 S2 — paged.
    final rows = await fetchAllPages(
      table: 'payment_intents',
      build: () => _client
          .from('payment_intents')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false)
          .order('id', ascending: true),
    );
    return rows
        .map((row) => PaymentIntent.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) async {
    final data = await _invokePayments({
      'action': 'config',
      'workspace_id': workspaceId,
    });
    if (data == null) return PaymentGatewayConfig.notDeployed;
    final providers = [
      for (final name in (data['providers'] as List? ?? const []))
        ?PaymentProvider.fromWire(name as String?),
    ];
    final missing = {
      for (final entry in (data['missing'] as Map? ?? const {}).entries)
        entry.key as String: [
          for (final v in (entry.value as List? ?? const [])) v as String,
        ],
    };
    return PaymentGatewayConfig(providers: providers, missing: missing);
  }

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(
    String workspaceId,
  ) async {
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

  @override
  Future<PaymentTestCheck> testPaymentKeys(String workspaceId) async =>
      PaymentTestCheck.fromJson(
        await _client.rpc<Object?>(
          'payment_test_check',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    await _client.rpc<dynamic>(
      'set_payment_credentials',
      params: {
        'p_workspace_id': workspaceId,
        'p_provider': provider.wireName,
        'p_config': config,
      },
    );
  }

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    await _client.rpc<dynamic>(
      'clear_payment_provider',
      params: {'p_workspace_id': workspaceId, 'p_provider': provider.wireName},
    );
  }

  @override
  Future<PaymentOrderStart> createPaymentOrder({
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

  /// Invokes the payment Edge Function, mapping an undeployed function
  /// (404) to a recognisable state instead of a crash.
  Future<Map<String, dynamic>?> _invokePayments(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'create-payment-order',
        body: body,
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on FunctionException catch (e, st) {
      if (e.status == 404) return null; // function not deployed
      // trace-exempt: not silent — rethrown as PaymentGatewayException via
      // throwWithStackTrace; the caller's runGuarded traces it.
      Error.throwWithStackTrace(
        PaymentGatewayException(
          e.status,
          e.details?.toString() ?? e.reasonPhrase ?? 'function error',
        ),
        st,
      );
    }
  }
}
