// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_money_repository.dart';

// #2386 — part 2 of SupabaseMoneyRepository, split out of supabase_money_repository.dart so no
// file holds the whole class.
extension _SupabaseMoneyRepositoryPart2 on SupabaseMoneyRepository {

  Future<String> _createInvoiceImpl({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,
    String buyerReference = '',
    String purchaseOrder = '',
  }) async {
    // #982 — a replacement is a correction of a document of record and
    // issues directly; a new invoice goes through the policy, which
    // holds it (pending) or applies it at once.
    if (replacesId != null) {
      final id = await _client.rpc<dynamic>('create_invoice', params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_period': period,
        'p_replaces': replacesId,
        'p_detailed': detailed,
        'p_buyer_reference': buyerReference,
        'p_purchase_order': purchaseOrder,
        'p_kind': kind.name,
      });
      return id as String;
    }
    final answer = await _client.rpc<dynamic>('request_invoice_issue', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_period': period,
      'p_kind': kind.name,
      'p_detailed': detailed,
      'p_allow_zero': false,
      'p_buyer_reference': buyerReference.isEmpty ? null : buyerReference,
      'p_purchase_order': purchaseOrder.isEmpty ? null : purchaseOrder,
    });
    return applyOrPending(answer as Map);
  }

  Future<List<String>> _invoiceIssueReadinessImpl({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
  }) async {
    final answer = await _client.rpc<dynamic>('invoice_issue_readiness', params: {
      'p_replaces': replacesId,
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_period': period,
      'p_kind': kind.name,
    });
    return [for (final key in answer as List) key as String];
  }

  Future<void> _voidInvoiceImpl(String invoiceId) async {
    await _client
        .rpc<dynamic>('request_invoice_void', params: {'p_invoice_id': invoiceId})
        .then((answer) => applyOrPending(answer as Map));
  }

  Future<void> _remindInvoiceImpl(String invoiceId) async {
    await _client.rpc<void>('record_invoice_reminder',
        params: {'p_invoice_id': invoiceId});
  }

  Future<Map<String, String>> _fetchDunningHoldsImpl(String workspaceId) async {
    final rows = await _client
        .from('invoice_dunning_holds')
        .select('invoice_id, reason')
        .eq('workspace_id', workspaceId)
        .isFilter('released_at', null);
    return {
      for (final row in rows)
        row['invoice_id'] as String: row['reason'] as String,
    };
  }

  Future<void> _placeDunningHoldImpl(
    String invoiceId, {
    required String reason,
    String note = '',
  }) =>
      _client.rpc<void>('place_dunning_hold', params: {
        'p_invoice_id': invoiceId,
        'p_reason': reason,
        'p_note': note,
      });

  Future<void> _releaseDunningHoldImpl(String invoiceId) => _client.rpc<void>(
      'release_dunning_hold', params: {'p_invoice_id': invoiceId});

  Future<void> _matchInvoiceImpl({
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

  Future<Map<String, InvoiceMatch>> _fetchInvoiceMatchesImpl(
    String workspaceId,
  ) async {
    // #1885 — paged to the end, in a total order: the handoff's payments,
    // totals and digest are built from this, and a read cut at the
    // server's cap would shorten them without a word.
    final rows = await fetchAllPages(
      table: 'invoice_matches',
      build: () => _client
          .from('invoice_matches')
          .select('invoice_id, paid_cents, resolution, note, status, '
              'payment_ledger_id, matched_at, by_name, writeoff_at, event_id')
          .eq('workspace_id', workspaceId)
          .order('invoice_id', ascending: true),
    );
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
          // #841 — who released it, reachable from the document.
          eventId: row['event_id'] as String?,
        ),
    };
  }

  Future<Map<String, List<TaxPointPayment>>> _fetchInvoiceInstalmentsImpl(
    String workspaceId,
  ) async {
    // #2355 — paged to the end like the matches: a declaration built
    // from a cut read would drop instalments without a word.
    final rows = await fetchAllPages(
      table: 'invoice_match_payments',
      build: () => _client
          .from('invoice_match_payments')
          .select('id, invoice_id, amount_cents, matched_at')
          .eq('workspace_id', workspaceId)
          .order('id', ascending: true),
    );
    final out = <String, List<TaxPointPayment>>{};
    for (final row in rows) {
      out.putIfAbsent(row['invoice_id'] as String, () => []).add(
            TaxPointPayment(
              DateTime.parse(row['matched_at'] as String).toLocal(),
              (row['amount_cents'] as num).toInt(),
            ),
          );
    }
    return out;
  }

  Future<List<ReminderEvidence>> _fetchReminderEvidenceImpl(String invoiceId) async {
    final rows = await _client.rpc<dynamic>('invoice_reminder_evidence',
        params: {'p_invoice_id': invoiceId});
    return [
      for (final row in (rows as List? ?? const []))
        ReminderEvidence.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<Statement> _fetchStatementImpl(String memberId, String period) async {
    final result = await _client.rpc<dynamic>('member_statement', params: {
      'p_member_id': memberId,
      'p_period': period,
    }) as Map<String, dynamic>;
    // Parsing lives in the domain (Statement.fromRpc) so the #170
    // supplement-field tolerance is pure-Dart testable.
    return Statement.fromRpc(result);
  }

  Future<List<LedgerEntry>> _fetchLedgerImpl(String memberId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return rows.map(_ledgerFromRow).whereType<LedgerEntry>().toList();
  }

  // #1148 — a ledger row whose kind or category this build does not
  // know is SKIPPED and traced, never mis-filed: reading a widened
  // category as "expense" would move money in the statement. Every
  // other list degrades to a fallback; money degrades to absence.
  LedgerEntry? _ledgerFromRow(Map<String, dynamic> row) {
    final kind = LedgerKind.values.asNameMap()[row['kind'] as String?];
    final category =
        LedgerCategory.values.asNameMap()[row['category'] as String?];
    if (kind == null || category == null) {
      TraceLogger.instance.warn('money',
          "ledger row ${row['id']} skipped: unknown kind/category ${row['kind']}/${row['category']}");
      return null;
    }
    return LedgerEntry(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        memberId: row['member_id'] as String,
        kind: kind,
        category: category,
        amountCents: row['amount_cents'] as int,
        description: row['description'] as String,
        period: row['period'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        occurredOn: row['occurred_on'] == null
            ? null
            : DateTime.parse(row['occurred_on'] as String),
      );
  }

  Future<List<LedgerEntry>> _fetchWorkspaceLedgerImpl(String workspaceId) async {
    // #1310 S2 — paged; the whole ledger is an export read.
    final rows = await fetchAllPages(
      table: 'ledger_entries',
      build: () => _client
          .from('ledger_entries')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false)
          .order('id', ascending: true),
    );
    return rows.map(_ledgerFromRow).whereType<LedgerEntry>().toList();
  }

  Future<List<PaymentIntent>> _fetchPaymentIntentsImpl(String workspaceId) async {
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

  Future<String> _recordPaymentImpl({
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
          : isoDay(paidOn),
      'p_period': period,
    });
    return result as String;
  }

  Future<void> _recordServiceChargeImpl({
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

  Future<List<ExpenseSchedule>> _fetchExpenseSchedulesImpl(String workspaceId) async {
    final rows = await _client
        .from('expense_schedules')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List) ExpenseSchedule.fromDb(r as Map<String, dynamic>),
    ];
  }

  Future<String> _createExpenseScheduleImpl({
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
    final id = await _client.rpc<dynamic>('create_expense_schedule', params: {
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

  Future<void> _cancelExpenseScheduleImpl(String scheduleId) => _client
      .rpc('cancel_expense_schedule', params: {'p_schedule_id': scheduleId});

  Future<int> _sweepExpenseSchedulesImpl(String workspaceId) async {
    final n = await _client
        .rpc<void>('sweep_expense_schedules',
            params: {'p_workspace_id': workspaceId});
    return (n as num?)?.toInt() ?? 0;
  }

  Future<List<ExpenseOccurrence>> _fetchExpenseOccurrencesImpl(
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

  Future<void> _confirmExpenseOccurrenceImpl({
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

  Future<String> _submitExpenseImpl({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
    Map<String, Object?>? vat,
  }) async {
    final result = await _client.rpc<dynamic>('submit_expense', params: {
      'p_workspace_id': workspaceId,
      'p_amount_cents': amountCents,
      'p_category': category,
      'p_description': description,
      // #731 — a supply: {name | service_id, quantity, unit_price_cents}.
      'p_supply': supply,
      // #2357 — sent only with VAT, so an older server still answers.
      'p_vat': ?vat,
    });
    return result as String;
  }

  Future<List<FeeBand>> _fetchFeeBandsImpl(String workspaceId) async {
    final rows = await _client
        .from('fee_bands')
        .select()
        .eq('workspace_id', workspaceId)
        .order('from_pct', ascending: true);
    return rows
        .map(
          (row) => FeeBand(
            system: SystemColumns.fromRow(row),
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
}
