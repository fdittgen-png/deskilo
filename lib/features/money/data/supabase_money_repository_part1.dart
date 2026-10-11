// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_money_repository.dart';

// #2386 — part 1 of SupabaseMoneyRepository, split out of supabase_money_repository.dart so no
// file holds the whole class.
extension _SupabaseMoneyRepositoryPart1 on SupabaseMoneyRepository {
  Future<List<Invoice>> _fetchInvoicesImpl(String workspaceId) async {
    // #1310 S2 — paged: the register and the export both read all of
    // them, and a workspace outlives 1000 invoices.
    final rows = await fetchAllPages(
      table: 'invoices',
      build: () => _client
          .from('invoices')
          // #1913 — the frozen due date travels with the invoice.
          .select('*, invoice_maturities(due_on, basis)')
          .eq('workspace_id', workspaceId)
          .order('issued_at', ascending: false)
          .order('id', ascending: true),
    );
    return rows.map(Invoice.fromRow).toList();
  }

  Future<List<VatDeclaration>> _fetchVatDeclarationsImpl(
      String workspaceId) async {
    final rows = await _client
        .from('vat_declarations')
        .select()
        .eq('workspace_id', workspaceId)
        .order('period_start', ascending: false);
    return rows.map(VatDeclaration.fromRow).toList();
  }

  Future<String> _saveVatDeclarationImpl({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    // #2357 — the period alone: the server computes the figures.
    final id = await _client.rpc<dynamic>('save_vat_declaration', params: {
      'p_workspace_id': workspaceId,
      'p_period_start': periodStart.toIso8601String().substring(0, 10),
      'p_period_end': periodEnd.toIso8601String().substring(0, 10),
    });
    return id as String;
  }

  Future<void> _markVatDeclarationSubmittedImpl({
    required String declarationId,
    required String channel,
    required String receipt,
  }) async {
    await _client.rpc<void>('mark_vat_declaration_submitted', params: {
      'p_declaration_id': declarationId,
      'p_channel': channel,
      'p_receipt': receipt,
    });
  }

  Future<InvoicePdfTemplate> _fetchInvoicePdfTemplateImpl(
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

  Future<void> _setInvoicePdfTemplateImpl(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async {
    // #982 — through the matrix (designDocuments), not the owner-only
    // row update.
    await _client.rpc<dynamic>('set_invoice_pdf_template', params: {
      'p_workspace_id': workspaceId,
      'p_template': template.toJson(),
    });
  }

  Future<List<String>> _listReportImagesImpl(String workspaceId) async {
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

  Future<void> _uploadReportImageImpl(
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

  Future<Uint8List?> _fetchReportImageImpl(
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

  Future<void> _settleCreditInvoiceImpl(String invoiceId,
      {String note = ''}) async {
    // #982 — through the refund policy.
    final answer = await _client.rpc<dynamic>('request_refund', params: {
      'p_invoice_id': invoiceId,
      'p_note': note,
    });
    applyOrPending(answer as Map);
  }

  Future<Set<String>> _fetchConsumedPaymentIdsImpl(String workspaceId) async {
    final rows = await _client
        .from('invoice_match_payments')
        .select('payment_ledger_id')
        .eq('workspace_id', workspaceId);
    return {
      for (final row in rows) row['payment_ledger_id'] as String,
    };
  }

  Future<MemberAccount> _fetchMemberAccountImpl(String memberId) async {
    final result = await _client.rpc<dynamic>('member_account', params: {
      'p_member_id': memberId,
    });
    return MemberAccount.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<DunningRules> _fetchDunningRulesImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('dunning_rules')
        .eq('id', workspaceId)
        .single();
    return DunningRules.fromJson(
      row['dunning_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<String> _settleInvoicesImpl({
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

  Future<BillingRules> _fetchBillingRulesImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    return BillingRules.fromJson(
      row['billing_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<WorkspaceStatus> _fetchWorkspaceStatusImpl(
      String workspaceId, String from, String to) async {
    final r = await _client.rpc<dynamic>('workspace_status', params: {
      'p_workspace_id': workspaceId,
      'p_from': from,
      'p_to': to,
    });
    return WorkspaceStatus.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<RepartitionRule> _fetchRepartitionRuleImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    final rules = (row['billing_rules'] as Map?)?.cast<String, dynamic>();
    return RepartitionRule.fromJson(
        (rules?['repartition'] as Map?)?.cast<String, dynamic>());
  }

  Future<void> _setRepartitionRuleImpl(
      String workspaceId, RepartitionRule rule) async {
    await _client.rpc<dynamic>('set_repartition_rule', params: {
      'p_workspace_id': workspaceId,
      'p_rule': rule.toJson(),
    });
  }

  Future<void> _setBillingRulesImpl(String workspaceId, BillingRules rules) async {
    // #816 — through the RPC gated on the `workspaceSettings` permission
    // (0144); the row's RLS was owner-only and ignored the matrix.
    await _client.rpc<void>('set_billing_rules', params: {
      'p_workspace_id': workspaceId,
      'p_rules': rules.toJson(),
    });
  }

  Future<int> _sweepBillingInvoicesImpl(String workspaceId) async {
    final result = await _client.rpc<dynamic>('sweep_billing_invoices', params: {
      'p_workspace_id': workspaceId,
    });
    return (result as num?)?.toInt() ?? 0;
  }

  Future<PriceNegotiation> _fetchPriceNegotiationImpl(String memberId) async =>
      PriceNegotiation.fromJson(await _client.rpc<dynamic>(
          'member_price_negotiation',
          params: {'p_member_id': memberId}) as Map<String, dynamic>);

  Future<void> _proposePriceNegotiationImpl({
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

  Future<int> _sweepPaymentRemindersImpl(String workspaceId) async {
    final n = await _client.rpc<Object?>(
      'sweep_payment_reminders',
      params: {'p_workspace_id': workspaceId},
    );
    return (n as num?)?.toInt() ?? 0;
  }

  Future<void> _setDunningRulesImpl(
    String workspaceId,
    DunningRules rules,
  ) async {
    // #816 — see setBillingRules.
    await _client.rpc<void>('set_dunning_rules', params: {
      'p_workspace_id': workspaceId,
      'p_rules': rules.toJson(),
    });
  }

  Future<String> _verifyInvoiceSignatureImpl(String invoiceId) async {
    final r = await _client.rpc<dynamic>('verify_invoice_signature',
        params: {'p_invoice_id': invoiceId});
    return r as String? ?? 'unverifiable';
  }

  Future<List<NumberSequence>> _fetchNumberSequencesImpl(String workspaceId) async {
    final rows = await _client
        .from('number_sequences')
        .select()
        .eq('workspace_id', workspaceId)
        .order('journal');
    final byJournal = {
      for (final r in rows) r['journal'] as String: NumberSequence.fromDb(r),
    };
    // Every journal the app knows is listed, seeded or not: the screen
    // shows the default a lazy row would take, so a series that was
    // never touched is still visible beside the ones that were.
    return [
      for (final j in NumberSequence.journals)
        byJournal[j] ?? NumberSequence.defaultsFor(j),
    ];
  }

  Future<void> _setNumberSequenceImpl(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  }) async {
    await _client.rpc<dynamic>(
      'set_number_sequence',
      params: {
        'p_workspace_id': workspaceId,
        'p_journal': sequence.journal,
        'p_prefix': sequence.prefix,
        'p_suffix': sequence.suffix,
        'p_date_part': NumberSequence.datePartWire(sequence.datePart),
        'p_digits': sequence.digits,
        'p_reset': NumberSequence.resetWire(sequence.reset),
        'p_next_value': ?raiseNextValueTo,
      },
    );
  }

  Future<String> _previewDocumentNumberImpl(
    String workspaceId,
    String journal,
  ) async {
    final r = await _client.rpc<dynamic>(
      'preview_document_number',
      params: {'p_workspace_id': workspaceId, 'p_journal': journal},
    );
    return r as String;
  }

  Future<String> _distributeExpenseImpl({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  }) async {
    final id = await _client.rpc<dynamic>('distribute_expense', params: {
      'p_workspace_id': workspaceId,
      'p_title': title,
      'p_amount_cents': amountCents,
      'p_method': method.name,
      'p_period': period,
      'p_shares': [for (final s in shares) s.toJson()],
      'p_source_event_id': sourceEventId,
    });
    return id as String;
  }

  Future<List<UsageRecord>> _fetchUsageRecordsImpl({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async {
    final data = await _client.rpc<dynamic>('usage_records_for', params: {
      'p_workspace_id': workspaceId,
      'p_period': period,
      'p_member_id': memberId,
    });
    final rows = (data as Map)['records'] as List? ?? const [];
    return [
      for (final row in rows)
        UsageRecord.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  Future<String> _requestUsageCorrectionImpl(
    String recordId, {
    String reason = '',
  }) async {
    final id = await _client.rpc<dynamic>('request_usage_correction', params: {
      'p_record_id': recordId,
      'p_reason': reason,
    });
    return id as String;
  }

  Future<String> _requestUsageRecordDeleteImpl(
    String recordId, {
    String reason = '',
  }) async {
    final id =
        await _client.rpc<dynamic>('request_usage_record_delete', params: {
      'p_record_id': recordId,
      'p_reason': reason,
    });
    return id as String;
  }

  Future<List<ExpenseRepartition>> _fetchExpenseRepartitionsImpl(
      String workspaceId) async {
    final rows = await _client
        .from('expense_repartitions')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        ExpenseRepartition.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
