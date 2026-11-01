// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/reminder_evidence.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';

import '../money_repository.dart';

/// #2591 — the demo's invoice reads, answered from one space's in-memory
/// money store ([FakeMoneyRepository]); every other port of that space reads
/// and writes the same store.
class DemoInvoiceQueries implements InvoiceQueries {
  DemoInvoiceQueries(this._m, {this.ownOnlyFor});

  final FakeMoneyRepository _m;

  /// The member whose OWN invoices are all the reader may see, or null when
  /// the reader sees the whole register (the server's `invoices_select`,
  /// 0131: a member without viewFinances or issueInvoices reads only theirs).
  String? Function()? ownOnlyFor;

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async {
    final own = ownOnlyFor?.call();
    return List.unmodifiable(
      own == null ? _m.invoices : _m.invoices.where((i) => i.memberId == own),
    );
  }

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async => {
    ..._m.consumedPaymentIds,
    for (final match in _m.invoiceMatchesStore.values) ?match.paymentLedgerId,
  };

  @override
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async => [
    for (final key in _m.invoiceMissing)
      // #2440 — the server stops asking once a reason is given.
      if (key != 'correction_reason' || correctionReason.isEmpty) key,
  ];
  Future<CommandReceipt> _outcome(String workspaceId, String requestId) async {
    final id = _m.invoiceReceipts['$workspaceId|$requestId'];
    return id == null
        ? const CommandReceipt(CommandReceiptState.notObserved)
        : CommandReceipt(CommandReceiptState.applied, invoiceId: id);
  }

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async => Map.of(_m.invoiceMatchesStore);

  @override
  Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(
    String workspaceId,
  ) async => {
    for (final entry in _m.invoiceInstalmentsStore.entries)
      entry.key: List.of(entry.value),
  };

  /// #1922 — the demo sends by hand only, and its share sheet always
  /// completes: every reminder is the sender's declaration.
  @override
  Future<List<ReminderEvidence>> fetchReminderEvidence(
    String invoiceId,
  ) async => [
    for (final (i, at)
        in (_m.invoiceReminders[invoiceId] ?? const <DateTime>[]).indexed)
      ReminderEvidence(
        intentId: '$invoiceId-reminder-$i',
        level: i + 1,
        origin: 'manual',
        status: 'declared_delivered',
        preparedAt: at,
      ),
  ];

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async {
    final lines = _m.derivedLines(memberId, period);
    return (
      lines: lines,
      totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
    );
  }

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) async => {
    for (final entry in _m.invoiceReminders.entries)
      if (entry.value.isNotEmpty)
        entry.key: (count: entry.value.length, last: entry.value.last),
  };

  @override
  Future<CommandReceipt> invoiceCommandOutcome({
    required String workspaceId,
    required String requestId,
  }) => _outcome(workspaceId, requestId);

  /// Mirrors invoice_lines_for (0062): positions derive EXCLUSIVELY
  /// from the period's statement + confirmed ledger charges — nothing
  /// is accepted from the caller.
  List<InvoiceLine> derivedLines(String memberId, String period) {
    final s = _m.statements[period] ?? _m.statement.copyWith(period: period);
    return [
      if (s.feeCents > 0)
        InvoiceLine(
          kind: 'subscription',
          label: '${s.subscriptionPct}',
          amountCents: s.feeCents,
        ),
      if (s.overageCents > 0)
        InvoiceLine(
          kind: 'overage',
          label: '',
          quantity: s.extraHalfDays,
          amountCents: s.overageCents,
        ),
      if (s.accessorySupplementCents > 0)
        InvoiceLine(
          kind: 'accessories',
          label: '',
          amountCents: s.accessorySupplementCents,
        ),
      if (s.levelSupplementCents > 0)
        InvoiceLine(
          kind: 'level',
          label: '',
          amountCents: s.levelSupplementCents,
        ),
      if (s.officeSupplementCents > 0)
        InvoiceLine(
          kind: 'office',
          label: '',
          amountCents: s.officeSupplementCents,
        ),
      if (s.deskSupplementCents > 0)
        InvoiceLine(
          kind: 'desk',
          label: '',
          amountCents: s.deskSupplementCents,
        ),
      for (final entry in _m.ledger)
        if (entry.memberId == memberId &&
            entry.period == period &&
            ((entry.kind == LedgerKind.charge &&
                    (entry.category == LedgerCategory.service ||
                        entry.category == LedgerCategory.package ||
                        entry.category == LedgerCategory.adjustment)) ||
                (entry.kind == LedgerKind.credit &&
                    (entry.category == LedgerCategory.payment ||
                        entry.category == LedgerCategory.expense ||
                        entry.category == LedgerCategory.adjustment))))
          InvoiceLine(
            kind: entry.category.name,
            label: entry.description,
            // 0063 — credits net against the charges: the total IS
            // the solde.
            amountCents: entry.kind == LedgerKind.credit
                ? -entry.amountCents
                : entry.amountCents,
          ),
    ];
  }
}
