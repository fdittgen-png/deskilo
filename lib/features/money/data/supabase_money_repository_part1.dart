// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_money_repository.dart';

// #2386 — part 1 of SupabaseMoneyRepository, split out of supabase_money_repository.dart so no
// file holds the whole class.
extension _SupabaseMoneyRepositoryPart1 on SupabaseMoneyRepository {

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

}
