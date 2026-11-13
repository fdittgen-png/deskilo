// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673, #3840 — the Demo's answer to the customer statement snapshot the
// customer page reads: the same figures, from the Demo's own rows
// (customerStatementOfPage), one balance per currency. The Demo has no
// server, so it has no allocation detail.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../../../features/money/application/customer_statement_of_page.dart';
import '../../../../features/money/application/unassigned_money.dart';
import '../../../../features/money/domain/dunning.dart';
import '../../../../features/money/domain/invoice_queries.dart';
import '../../../../features/money/domain/ledger_entry.dart';
import '../../../../features/money/presentation/invoicing/receivables_adapter.dart';
import '../../../../features/money/providers/customer_statement_providers.dart';
import '../../demo_fixture.dart';

class _DemoCustomerStatementReader implements CustomerStatementReader {
  const _DemoCustomerStatementReader({
    required this.invoices,
    required this.ledgerOf,
    required this.currencyOf,
  });

  final InvoiceQueries invoices;

  /// The workspace's ledger.
  final Future<List<LedgerEntry>> Function(String workspaceId) ledgerOf;

  /// The currency the workspace keeps its ledger in.
  final String Function(String workspaceId) currencyOf;

  @override
  Future<CustomerStatement> read(
    String workspaceId,
    String memberId,
    DateTime asOf,
  ) => _at(workspaceId, memberId, asOf, cutoff: null);

  /// #3839 — the open items at [cutoff] (null: everything the Demo holds):
  /// the documents issued, the payments recorded and the matches made
  /// before it.
  Future<CustomerStatement> _at(
    String workspaceId,
    String memberId,
    DateTime asOf, {
    required DateTime? cutoff,
  }) async {
    bool before(DateTime at) => cutoff == null || at.isBefore(cutoff);
    final all = [
      for (final i in await invoices.fetchInvoices(workspaceId))
        if (before(i.issuedAt)) i,
    ];
    final matches = {
      for (final e in (await invoices.fetchInvoiceMatches(workspaceId)).entries)
        if (before(e.value.matchedAt)) e.key: e.value,
    };
    final receivables = ReceivablesReader(
      matches: matches,
      reminders: const {},
      rules: const DunningRules(),
      now: asOf,
      dayOf: (instant) => instant,
    ).read(all);
    final unassigned = unassignedPaymentsByCustomer(
      ledger: [
        for (final e in await ledgerOf(workspaceId))
          if (before(e.createdAt)) e,
      ],
      use: paymentUseOf(
        junction: await invoices.fetchConsumedPaymentIds(workspaceId),
        moved: const {},
      ),
      invoices: all,
    );
    return customerStatementOfPage(
      customerId: memberId,
      asOf: asOf,
      receivables: receivables,
      unassigned: unassigned[memberId] ?? const [],
      ledgerCurrency: currencyOf(workspaceId),
    );
  }

  /// #3839 — the period as the server builds it: the open items at its
  /// start, again just after each instant at which a document, a payment or
  /// a match of the customer appeared, and at its end.
  @override
  Future<CustomerStatementPeriod> period(
    String workspaceId,
    String memberId,
    DateTime from,
    DateTime to,
  ) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    final theirs = [
      for (final i in await invoices.fetchInvoices(workspaceId))
        if (i.memberId == memberId) i,
    ];
    final instants = <DateTime>{
      for (final i in theirs) i.issuedAt,
      for (final m in (await invoices.fetchInvoiceMatches(workspaceId)).values)
        if (theirs.any((i) => i.id == m.invoiceId)) m.matchedAt,
      for (final e in await ledgerOf(workspaceId))
        if (e.memberId == memberId) e.createdAt,
    }.where((t) => !t.isBefore(start) && t.isBefore(end)).toList()..sort();
    const micro = Duration(microseconds: 1);
    return statementPeriodOf(
      from: start,
      to: DateTime(to.year, to.month, to.day),
      opening: await _at(workspaceId, memberId, start, cutoff: start),
      steps: [
        for (final t in instants)
          (t, await _at(workspaceId, memberId, t, cutoff: t.add(micro))),
      ],
      closing: await _at(workspaceId, memberId, end, cutoff: end),
    );
  }
}

/// #3673 — the Demo's statement reader over the session's [fixture]: the
/// page's own rules, since the Demo has no server to ask.
Override demoCustomerStatementOverride(DemoFixture fixture) =>
    customerStatementReaderProvider.overrideWithValue(
      _DemoCustomerStatementReader(
        invoices: fixture.money,
        ledgerOf: fixture.money.fetchWorkspaceLedger,
        currencyOf: (id) =>
            fixture.workspaces.workspaces
                .where((w) => w.id == id)
                .firstOrNull
                ?.currencyCode ??
            '',
      ),
    );
