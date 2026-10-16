// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../domain/billing_rules.dart';
import '../domain/invoice.dart';
import '../domain/invoice_queries.dart';
import '../domain/reminder_evidence.dart';
import '../domain/vat_tax_point.dart';
import 'invoice_preview_decoder.dart';
import 'invoice_reminder_fold.dart';

/// #2591 C1 — the invoice reads, with their own client. The bodies are the
/// ones that lived in the money repository's part files.
class SupabaseInvoiceQueries implements InvoiceQueries {
  SupabaseInvoiceQueries(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async {
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

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async {
    // #2587 — paged to the end: a list cut at the server's cap would offer
    // an already-consumed payment again. The match command still rechecks
    // (and the unique payment_ledger_id refuses) the stale candidate.
    final rows = await fetchAllPages(
      table: 'invoice_match_payments',
      build: () => _client
          .from('invoice_match_payments')
          .select('id, payment_ledger_id')
          .eq('workspace_id', workspaceId)
          .order('id', ascending: true),
    );
    return {for (final row in rows) row['payment_ledger_id'] as String};
  }

  @override
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async {
    final answer = await _client.rpc<dynamic>(
      'invoice_issue_readiness',
      params: {
        'p_replaces': replacesId,
        'p_correction_reason': correctionReason,
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_period': period,
        'p_kind': kind.name,
      },
    );
    return [for (final key in answer as List) key as String];
  }

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async {
    // #1885 — paged to the end, in a total order: the handoff's payments,
    // totals and digest are built from this, and a read cut at the
    // server's cap would shorten them without a word.
    final rows = await fetchAllPages(
      table: 'invoice_matches',
      build: () => _client
          .from('invoice_matches')
          .select(
            'invoice_id, paid_cents, resolution, note, status, '
            'payment_ledger_id, matched_at, by_name, writeoff_at, event_id',
          )
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

  @override
  Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(
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
      out
          .putIfAbsent(row['invoice_id'] as String, () => [])
          .add(
            TaxPointPayment(
              DateTime.parse(row['matched_at'] as String).toLocal(),
              (row['amount_cents'] as num).toInt(),
            ),
          );
    }
    return out;
  }

  @override
  Future<List<ReminderEvidence>> fetchReminderEvidence(String invoiceId) async {
    final rows = await _client.rpc<dynamic>(
      'invoice_reminder_evidence',
      params: {'p_invoice_id': invoiceId},
    );
    return [
      for (final row in (rows as List? ?? const []))
        ReminderEvidence.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async {
    final raw = await _client.rpc<dynamic>(
      'preview_invoice',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_period': period,
      },
    );
    return decodeInvoicePreview(raw);
  }

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) async {
    // #2587 — paged to the end in a total order: one request is cut at the
    // server's cap, which made the reminder count and the latest date wrong.
    final rows = await fetchAllPages(
      table: 'invoice_reminders',
      build: () => _client
          .from('invoice_reminders')
          .select('id, invoice_id, sent_at')
          .eq('workspace_id', workspaceId)
          .order('id', ascending: true),
    );
    return foldInvoiceReminders(rows);
  }
}
