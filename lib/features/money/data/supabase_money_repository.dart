// SPDX-License-Identifier: 0BSD
import 'dart:convert' show base64Encode;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice.dart';
import '../domain/vat_declaration.dart';
import '../domain/member_account.dart';
import '../domain/billing_rules.dart';
import '../domain/dunning.dart';
import '../domain/price_negotiation.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/expense_schedule.dart';
import '../domain/fee_band.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/package.dart';
import '../domain/payment_method.dart';
import '../domain/payment_provider.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/vat_rate.dart';
import '../domain/subscription_levels.dart';
import '../domain/payment_intent.dart';

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
  Future<List<VatDeclaration>> fetchVatDeclarations(
      String workspaceId) async {
    final rows = await _client
        .from('vat_declarations')
        .select()
        .eq('workspace_id', workspaceId)
        .order('period_start', ascending: false);
    return rows.map(VatDeclaration.fromRow).toList();
  }

  @override
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<VatDeclarationLine> lines,
    required int totalNetCents,
    required int totalVatCents,
    required String currency,
    required int invoiceCount,
  }) async {
    final id = await _client.rpc<dynamic>('save_vat_declaration', params: {
      'p_workspace_id': workspaceId,
      'p_period_start': periodStart.toIso8601String().substring(0, 10),
      'p_period_end': periodEnd.toIso8601String().substring(0, 10),
      'p_lines': [for (final line in lines) line.toJson()],
      'p_total_net_cents': totalNetCents,
      'p_total_vat_cents': totalVatCents,
      'p_currency': currency,
      'p_invoice_count': invoiceCount,
    });
    return id as String;
  }

  @override
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    String receipt = '',
  }) async {
    await _client.rpc<void>('mark_vat_declaration_submitted', params: {
      'p_declaration_id': declarationId,
      'p_channel': channel,
      'p_receipt': receipt,
    });
  }

  @override
  Future<EInvoiceSubmission> sendVatDeclaration({
    required String workspaceId,
    required String declarationId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final data = await _invokeSend({
      'workspace_id': workspaceId,
      'declaration_id': declarationId,
      'file_name': fileName,
      'mime_type': mimeType,
      'content_base64': base64Encode(bytes),
    });
    if (data == null) {
      return const EInvoiceSubmission(
        status: EInvoiceSubmissionStatus.failed,
        detail: 'not_deployed',
      );
    }
    final status = data['status'] as String?;
    return EInvoiceSubmission(
      status: EInvoiceSubmissionStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => EInvoiceSubmissionStatus.failed,
      ),
      externalId: data['external_id'] as String? ?? '',
      detail: data['detail'] as String? ?? (data['error'] as String? ?? ''),
    );
  }

  @override
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(
    String workspaceId,
  ) async {
    final row = await _client
        .from('workspaces')
        .select('invoice_pdf_template')
        .eq('id', workspaceId)
        .single();
    return InvoicePdfTemplate.fromJson(
      row['invoice_pdf_template'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async {
    await _client
        .from('workspaces')
        .update({'invoice_pdf_template': template.toJson()})
        .eq('id', workspaceId);
  }

  @override
  Future<List<String>> listReportImages(String workspaceId) async {
    // #488 — the report-image library lives beside the level backgrounds
    // in the private floor-plans bucket; the 0036 RLS (first path
    // segment = workspace) covers it member-read / owner-write.
    final entries = await _client.storage
        .from('floor-plans')
        .list(path: '$workspaceId/report');
    return [
      for (final entry in entries)
        if (entry.name.isNotEmpty) entry.name,
    ]..sort();
  }

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    await _client.storage.from('floor-plans').uploadBinary(
          '$workspaceId/report/$name',
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  @override
  Future<Uint8List?> fetchReportImage(
      String workspaceId, String name) async {
    try {
      return await _client.storage
          .from('floor-plans')
          .download('$workspaceId/report/$name');
    } on StorageException {
      // trace-exempt: an image deleted from the library is a normal
      // miss — the template renders without it by contract.
      return null;
    }
  }

  @override
  Future<void> settleCreditInvoice(String invoiceId,
      {String note = ''}) async {
    await _client.rpc<void>('settle_credit_invoice', params: {
      'p_invoice_id': invoiceId,
      'p_note': note,
    });
  }

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async {
    final rows = await _client
        .from('invoice_match_payments')
        .select('payment_ledger_id')
        .eq('workspace_id', workspaceId);
    return {
      for (final row in rows) row['payment_ledger_id'] as String,
    };
  }

  @override
  Future<MemberAccount> fetchMemberAccount(String memberId) async {
    final result = await _client.rpc<dynamic>('member_account', params: {
      'p_member_id': memberId,
    });
    return MemberAccount.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<DunningRules> fetchDunningRules(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('dunning_rules')
        .eq('id', workspaceId)
        .single();
    return DunningRules.fromJson(
      row['dunning_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<String> settleInvoices({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    String note = '',
  }) async {
    final id = await _client.rpc<dynamic>('settle_invoices', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_invoice_ids': invoiceIds,
      'p_note': note,
    });
    return id as String;
  }

  @override
  Future<BillingRules> fetchBillingRules(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    return BillingRules.fromJson(
      row['billing_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<void> setBillingRules(String workspaceId, BillingRules rules) async {
    // Same path as the dunning rules: the workspace row's own RLS decides
    // who may write it, so there is no RPC to keep in step with it.
    await _client
        .from('workspaces')
        .update({'billing_rules': rules.toJson()}).eq('id', workspaceId);
  }

  @override
  Future<int> sweepBillingInvoices(String workspaceId) async {
    final result = await _client.rpc<dynamic>('sweep_billing_invoices', params: {
      'p_workspace_id': workspaceId,
    });
    return (result as num?)?.toInt() ?? 0;
  }

  @override
  Future<PriceNegotiation> fetchPriceNegotiation(String memberId) async =>
      PriceNegotiation.fromJson(await _client.rpc<dynamic>(
          'member_price_negotiation',
          params: {'p_member_id': memberId}) as Map<String, dynamic>);

  @override
  Future<void> proposePriceNegotiation({
    required String memberId,
    int? feeCents,
    int? overageFeeCents,
    double? discountPercent,
    String note = '',
    DateTime? validFrom,
    int? subscriptionPct,
    Map<String, Map<String, int>> items = const {},
  }) =>
      _client.rpc<void>('propose_price_negotiation', params: {
        'p_member_id': memberId,
        'p_fee_cents': feeCents,
        'p_overage_fee_cents': overageFeeCents,
        'p_discount_percent': discountPercent,
        'p_note': note,
        'p_valid_from': validFrom?.toIso8601String().substring(0, 10),
        'p_subscription_pct': subscriptionPct, 'p_items': items,
      });

  @override
  Future<int> sweepPaymentReminders(String workspaceId) async {
    final n = await _client.rpc<Object?>(
      'sweep_payment_reminders',
      params: {'p_workspace_id': workspaceId},
    );
    return (n as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> setDunningRules(
    String workspaceId,
    DunningRules rules,
  ) async {
    await _client
        .from('workspaces')
        .update({'dunning_rules': rules.toJson()}).eq('id', workspaceId);
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
            // 0072 — so the preview can show the same VAT the document
            // will carry.
            vatPercent: (line['vat_percent'] as num?)?.toDouble() ?? 0,
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
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  }) async {
    await _client.rpc<void>('match_invoice', params: {
      'p_invoice_id': invoiceId,
      'p_payment_ledger_id': paymentLedgerId,
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
            'payment_ledger_id, matched_at, by_name, writeoff_at')
        .eq('workspace_id', workspaceId);
    return {
      for (final row in rows)
        row['invoice_id'] as String: InvoiceMatch(
          invoiceId: row['invoice_id'] as String,
          paidCents: (row['paid_cents'] as num).toInt(),
          resolution: row['resolution'] as String,
          note: row['note'] as String? ?? '',
          status: row['status'] as String? ?? 'confirmed',
          paymentLedgerId: row['payment_ledger_id'] as String?,
          matchedAt: DateTime.parse(row['matched_at'] as String).toLocal(),
          byName: row['by_name'] as String? ?? '',
          writeoffAt: row['writeoff_at'] == null
              ? null
              : DateTime.parse(row['writeoff_at'] as String).toLocal(),
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
    return rows.map(_ledgerFromRow).toList();
  }

  LedgerEntry _ledgerFromRow(Map<String, dynamic> row) => LedgerEntry(
        id: row['id'] as String,
        memberId: row['member_id'] as String,
        kind: LedgerKind.values.byName(row['kind'] as String),
        category: LedgerCategory.values.byName(row['category'] as String),
        amountCents: row['amount_cents'] as int,
        description: row['description'] as String,
        period: row['period'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        occurredOn: row['occurred_on'] == null
            ? null
            : DateTime.parse(row['occurred_on'] as String),
      );

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return rows.map(_ledgerFromRow).toList();
  }

  @override
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) async {
    final rows = await _client
        .from('payment_intents')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return rows
        .map((row) => PaymentIntent.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  }) async {
    final result = await _client.rpc<dynamic>('record_payment', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_amount_cents': amountCents,
      'p_note': note,
      'p_method': method?.wireName ?? '',
      // 0070 — a date, not a timestamp: what matters is the DAY the money
      // moved, in the payer's own calendar.
      'p_paid_on': paidOn == null
          ? null
          : '${paidOn.year}-${paidOn.month.toString().padLeft(2, '0')}'
              '-${paidOn.day.toString().padLeft(2, '0')}',
      'p_period': period,
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
  Future<List<ExpenseSchedule>> fetchExpenseSchedules(String workspaceId) async {
    final rows = await _client
        .from('expense_schedules')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List) ExpenseSchedule.fromDb(r as Map<String, dynamic>),
    ];
  }

  @override
  Future<String> createExpenseSchedule({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) async {
    final id = await _client.rpc('create_expense_schedule', params: {
      'p_workspace_id': workspaceId,
      'p_title': title,
      'p_amount_cents': amountCents,
      'p_starts_on': startsOn.toIso8601String().substring(0, 10),
      'p_unit': unit.name,
      'p_every': every,
      'p_repeat_count': repeatCount,
      'p_ends_on': endsOn?.toIso8601String().substring(0, 10),
      'p_description': description,
    });
    return id as String;
  }

  @override
  Future<void> cancelExpenseSchedule(String scheduleId) => _client
      .rpc('cancel_expense_schedule', params: {'p_schedule_id': scheduleId});

  @override
  Future<int> sweepExpenseSchedules(String workspaceId) async {
    final n = await _client
        .rpc('sweep_expense_schedules', params: {'p_workspace_id': workspaceId});
    return (n as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(
      String workspaceId) async {
    final rows = await _client
        .from('expense_occurrences')
        .select('*, expense_schedules(title, amount_cents)')
        .eq('workspace_id', workspaceId)
        .order('due_on');
    return [
      for (final r in rows as List)
        ExpenseOccurrence.fromDb(r as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> confirmExpenseOccurrence({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) =>
      _client.rpc('confirm_expense_occurrence', params: {
        'p_occurrence_id': occurrenceId,
        'p_amount_cents': amountCents,
        'p_reason': reason,
        'p_note': note,
      });

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
  }) async {
    final result = await _client.rpc<dynamic>('submit_expense', params: {
      'p_workspace_id': workspaceId,
      'p_amount_cents': amountCents,
      'p_category': category,
      'p_description': description,
      // #731 — a supply: {name | service_id, quantity, unit_price_cents}.
      'p_supply': supply,
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
        vatRateId: row['vat_rate_id'] as String? ?? '',
        stock: row['stock'] as int?,
      );

  // ── VAT rates (0072) ────────────────────────────────────────────────

  @override
  Future<List<VatRate>> fetchVatRates(String workspaceId) async {
    final rows = await _client
        .from('vat_rates')
        .select()
        .eq('workspace_id', workspaceId)
        .order('percent', ascending: false);
    return rows.map(VatRate.fromRow).toList();
  }

  @override
  Future<void> setVatRates(String workspaceId, List<VatRate> rates) async {
    await _client.rpc<void>('set_vat_rates', params: {
      'p_workspace_id': workspaceId,
      'p_rates': [for (final rate in rates) rate.toJson()],
    });
  }

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
    String? vatRateId,
  }) async {
    final row = await _client
        .from('services')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'price_cents': priceCents,
          // '' means "the workspace default", which the column stores as
          // NULL — the resolution lives in one place, the server.
          'vat_rate_id': (vatRateId ?? '').isEmpty ? null : vatRateId,
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
    String? vatRateId,
  }) async {
    final row = await _client
        .from('services')
        .update({
          'name': ?name,
          'price_cents': ?priceCents,
          'active': ?active,
          if (vatRateId != null)
            'vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
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
    String? vatRateId,
  }) async {
    final row = await _client
        .from('packages')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'days': days,
          'price_cents': priceCents,
          'vat_rate_id': (vatRateId ?? '').isEmpty ? null : vatRateId,
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
    String? vatRateId,
  }) async {
    final row = await _client
        .from('packages')
        .update({
          'name': ?name,
          'days': ?days,
          'price_cents': ?priceCents,
          'active': ?active,
          if (vatRateId != null)
            'vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
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

  // ── e-invoice transmission (0071/0073) ──────────────────────────────

  /// Same seam as the payment function: a 404 means "not deployed", which
  /// is a configuration answer, not an error.
  Future<Map<String, dynamic>?> _invokeSend(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'send-e-invoice',
        body: body,
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on FunctionException catch (e, st) {
      if (e.status == 404) return null;
      // A 409/502 carries the platform's own words in the body — surface
      // them rather than a generic failure.
      final details = e.details;
      if (details is Map) return Map<String, dynamic>.from(details);
      // trace-exempt: rethrown for the caller's runGuarded to trace.
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
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(
    String workspaceId,
  ) async {
    final data = await _invokeSend({
      'action': 'config',
      'workspace_id': workspaceId,
    });
    if (data == null) return EInvoiceGatewayConfig.notConfigured;
    return EInvoiceGatewayConfig(
      configured: data['configured'] == true,
      provider: data['provider'] as String? ?? 'generic',
      missing: [
        for (final field in (data['missing'] as List? ?? const []))
          field as String,
      ],
      environments: {
        for (final entry
            in (data['environments'] as Map? ?? const {}).entries)
          entry.key as String: entry.value == true,
      },
      // #568 — absent on a pre-destination function: the customer leg
      // then stays hidden (the deployment latch).
      destinations: {
        for (final entry
            in (data['destinations'] as Map? ?? const {}).entries)
          entry.key as String: EInvoiceDestination(
            configured: (entry.value as Map)['configured'] == true,
            missing: [
              for (final field
                  in ((entry.value as Map)['missing'] as List? ?? const []))
                field as String,
            ],
            environments: {
              for (final env in ((entry.value as Map)['environments']
                          as Map? ??
                      const {})
                  .entries)
                env.key as String: env.value == true,
            },
          ),
      },
    );
  }

  @override
  Future<EInvoiceSubmission> sendEInvoice({
    required String workspaceId,
    required String invoiceId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String environment = 'prod',
    String destination = 'government',
  }) async {
    final data = await _invokeSend({
      'workspace_id': workspaceId,
      'invoice_id': invoiceId,
      'file_name': fileName,
      'mime_type': mimeType,
      'content_base64': base64Encode(bytes),
      'environment': environment,
      'destination': destination,
    });
    if (data == null) {
      return const EInvoiceSubmission(
        status: EInvoiceSubmissionStatus.failed,
        detail: 'not_deployed',
      );
    }
    final status = data['status'] as String?;
    return EInvoiceSubmission(
      status: EInvoiceSubmissionStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => EInvoiceSubmissionStatus.failed,
      ),
      externalId: data['external_id'] as String? ?? '',
      detail: data['detail'] as String? ?? data['error'] as String? ?? '',
    );
  }

  @override
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  ) async {
    final rows = await _client
        .from('invoice_transmissions')
        .select()
        .eq('workspace_id', workspaceId)
        .order('sent_at', ascending: false);
    final latest = <String, InvoiceTransmission>{};
    for (final row in rows) {
      // Ordered newest first: the first row per invoice is the current one.
      final transmission = InvoiceTransmission.fromRow(row);
      latest.putIfAbsent(transmission.invoiceId, () => transmission);
    }
    return latest;
  }

  @override
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  ) async {
    await _client.rpc<void>('set_einvoice_credentials', params: {
      'p_workspace_id': workspaceId,
      'p_config': config,
    });
  }

  @override
  Future<void> clearEInvoiceCredentials(String workspaceId) async {
    await _client.rpc<void>('clear_einvoice_credentials', params: {
      'p_workspace_id': workspaceId,
    });
  }

  @override
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(
    String workspaceId,
  ) async {
    final data = await _client.rpc<dynamic>('einvoice_status', params: {
      'p_workspace_id': workspaceId,
    });
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    return EInvoiceProviderStatus(
      configured: map['configured'] == true,
      fields: {
        for (final entry in (map['fields'] as Map? ?? const {}).entries)
          entry.key as String: '${entry.value}',
      },
      secretsSet: [
        for (final name in (map['secrets_set'] as List? ?? const []))
          name as String,
      ],
    );
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
