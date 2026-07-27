// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice.dart';
import '../domain/fee_band.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/package.dart';
import '../domain/payment_method.dart';
import '../domain/payment_provider.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/subscription_levels.dart';

class SupabaseMoneyRepository implements MoneyRepository {
  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async {
    final rows = await _client
        .from('invoices')
        .select()
        .eq('workspace_id', workspaceId)
        .order('issued_at', ascending: false);
    return rows.map(Invoice.fromRow).toList();
  }

  @override
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
  }) async {
    final id = await _client.rpc<dynamic>('create_invoice', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_period': period,
      'p_replaces': replacesId,
      'p_detailed': detailed,
    });
    return id as String;
  }

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async {
    final raw = await _client.rpc<dynamic>('preview_invoice', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_period': period,
    }) as Map<String, dynamic>;
    return (
      lines: [
        for (final line in (raw['lines'] as List? ?? const []))
          InvoiceLine(
            kind: (line as Map)['kind'] as String? ?? '',
            label: line['label'] as String? ?? '',
            quantity: (line['quantity'] as num?)?.toInt() ?? 1,
            amountCents: (line['amount_cents'] as num).toInt(),
          ),
      ],
      totalCents: (raw['total_cents'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> voidInvoice(String invoiceId) async {
    await _client
        .rpc<void>('void_invoice', params: {'p_invoice_id': invoiceId});
  }

  @override
  Future<void> remindInvoice(String invoiceId) async {
    await _client.rpc<void>('record_invoice_reminder',
        params: {'p_invoice_id': invoiceId});
  }

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required int paidCents,
    required String resolution,
    String note = '',
  }) async {
    await _client.rpc<void>('match_invoice', params: {
      'p_invoice_id': invoiceId,
      'p_paid_cents': paidCents,
      'p_resolution': resolution,
      'p_note': note,
    });
  }

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('invoice_matches')
        .select('invoice_id, paid_cents, resolution, note, status, '
            'matched_at, by_name')
        .eq('workspace_id', workspaceId);
    return {
      for (final row in rows)
        row['invoice_id'] as String: InvoiceMatch(
          invoiceId: row['invoice_id'] as String,
          paidCents: (row['paid_cents'] as num).toInt(),
          resolution: row['resolution'] as String,
          note: row['note'] as String? ?? '',
          status: row['status'] as String? ?? 'confirmed',
          matchedAt: DateTime.parse(row['matched_at'] as String).toLocal(),
          byName: row['by_name'] as String? ?? '',
        ),
    };
  }

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('invoice_reminders')
        .select('invoice_id, sent_at')
        .eq('workspace_id', workspaceId);
    final result = <String, ({int count, DateTime last})>{};
    for (final row in rows) {
      final id = row['invoice_id'] as String;
      final at = DateTime.parse(row['sent_at'] as String).toLocal();
      final prev = result[id];
      result[id] = (
        count: (prev?.count ?? 0) + 1,
        last: prev == null || at.isAfter(prev.last) ? at : prev.last,
      );
    }
    return result;
  }

  SupabaseMoneyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    final result = await _client.rpc<dynamic>('member_statement', params: {
      'p_member_id': memberId,
      'p_period': period,
    }) as Map<String, dynamic>;
    // Parsing lives in the domain (Statement.fromRpc) so the #170
    // supplement-field tolerance is pure-Dart testable.
    return Statement.fromRpc(result);
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => LedgerEntry(
            id: row['id'] as String,
            memberId: row['member_id'] as String,
            kind: LedgerKind.values.byName(row['kind'] as String),
            category:
                LedgerCategory.values.byName(row['category'] as String),
            amountCents: row['amount_cents'] as int,
            description: row['description'] as String,
            period: row['period'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
  }) async {
    final result = await _client.rpc<dynamic>('record_payment', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_amount_cents': amountCents,
      'p_note': note,
      'p_method': method?.wireName ?? '',
    });
    return result as String;
  }

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    await _client.rpc<dynamic>('record_service_charge', params: {
      'p_workspace_id': workspaceId,
      'p_subject_member_id': subjectMemberId,
      'p_service_id': serviceId,
      'p_quantity': quantity,
      'p_period': ?period,
    });
  }

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
  }) async {
    final result = await _client.rpc<dynamic>('submit_expense', params: {
      'p_workspace_id': workspaceId,
      'p_amount_cents': amountCents,
      'p_category': category,
      'p_description': description,
    });
    return result as String;
  }

  @override
  Future<List<FeeBand>> fetchFeeBands(String workspaceId) async {
    final rows = await _client
        .from('fee_bands')
        .select()
        .eq('workspace_id', workspaceId)
        .order('from_pct', ascending: true);
    return rows
        .map(
          (row) => FeeBand(
            id: row['id'] as String,
            workspaceId: row['workspace_id'] as String,
            fromPct: row['from_pct'] as int,
            toPct: row['to_pct'] as int,
            feeCents: row['fee_cents'] as int,
            overageFeeCents: row['overage_fee_cents'] as int,
          ),
        )
        .toList();
  }

  @override
  Future<void> replaceFeeBands(
    String workspaceId,
    List<FeeBand> bands,
  ) async {
    await _client.rpc<dynamic>('replace_fee_bands', params: {
      'p_workspace_id': workspaceId,
      'p_bands': [
        for (final band in bands)
          {
            'from_pct': band.fromPct,
            'to_pct': band.toPct,
            'fee_cents': band.feeCents,
            'overage_fee_cents': band.overageFeeCents,
          },
      ],
    });
  }

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(
    String workspaceId,
  ) async {
    final row = await _client
        .from('workspaces')
        .select('subscription_levels')
        .eq('id', workspaceId)
        .single();
    return SubscriptionLevels.fromDb(
      row['subscription_levels'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  ) async {
    await _client
        .from('workspaces')
        .update({'subscription_levels': levels.toDb()}).eq(
      'id',
      workspaceId,
    );
  }

  ServiceItem _serviceFromRow(Map<String, dynamic> row) => ServiceItem(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        priceCents: row['price_cents'] as int,
        active: row['active'] as bool,
      );

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    var query =
        _client.from('services').select().eq('workspace_id', workspaceId);
    if (!includeInactive) query = query.eq('active', true);
    final rows = await query.order('name', ascending: true);
    return rows.map(_serviceFromRow).toList();
  }

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
  }) async {
    final row = await _client
        .from('services')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'price_cents': priceCents,
        })
        .select()
        .single();
    return _serviceFromRow(row);
  }

  @override
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
  }) async {
    final row = await _client
        .from('services')
        .update({
          'name': ?name,
          'price_cents': ?priceCents,
          'active': ?active,
        })
        .eq('id', serviceId)
        .select()
        .single();
    return _serviceFromRow(row);
  }

  @override
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    var query =
        _client.from('packages').select().eq('workspace_id', workspaceId);
    if (!includeInactive) query = query.eq('active', true);
    final rows = await query.order('days', ascending: true);
    return rows.map(Package.fromRow).toList();
  }

  @override
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
  }) async {
    final row = await _client
        .from('packages')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'days': days,
          'price_cents': priceCents,
        })
        .select()
        .single();
    return Package.fromRow(row);
  }

  @override
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
  }) async {
    final row = await _client
        .from('packages')
        .update({
          'name': ?name,
          'days': ?days,
          'price_cents': ?priceCents,
          'active': ?active,
        })
        .eq('id', packageId)
        .select()
        .single();
    return Package.fromRow(row);
  }

  @override
  Future<String> buyPackage(String workspaceId, String packageId) async {
    final result = await _client.rpc<dynamic>('buy_package', params: {
      'p_workspace_id': workspaceId,
      'p_package_id': packageId,
    });
    return result as String;
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
      for (final entry
          in (data['missing'] as Map? ?? const {}).entries)
        entry.key as String: [
          for (final v in (entry.value as List? ?? const [])) v as String,
        ],
    };
    return PaymentGatewayConfig(providers: providers, missing: missing);
  }

  @override
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
  }) async {
    final data = await _invokePayments({
      'provider': provider.wireName,
      'workspace_id': workspaceId,
      'member_id': memberId,
      'amount_cents': amountCents,
      'currency': currencyCode,
      'period': period,
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
    final approveUrl = data['approve_url'];
    if (approveUrl is! String || approveUrl.isEmpty) {
      throw PaymentGatewayException(500, 'no approve_url in $data');
    }
    return PaymentOrderStart(
      approveUrl: Uri.parse(approveUrl),
      orderId: data['order_id'] as String?,
    );
  }

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>>
      fetchPaymentGatewayStatus(String workspaceId) async {
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
  Future<void> setPaymentCredentials(
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

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    await _client.rpc<dynamic>('clear_payment_provider', params: {
      'p_workspace_id': workspaceId,
      'p_provider': provider.wireName,
    });
  }
}
