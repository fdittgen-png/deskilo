// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the Demo's customer statement: the same figures the customer page
// shows, from the Demo's own rows, by the page's rules
// (customerStatementOfPage) — the rules the parity test holds the server's
// snapshot to. The Demo has no server, so it has no allocation detail.
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
  ) async {
    final all = await invoices.fetchInvoices(workspaceId);
    final receivables = ReceivablesReader(
      matches: await invoices.fetchInvoiceMatches(workspaceId),
      reminders: const {},
      rules: const DunningRules(),
      now: asOf,
      dayOf: (instant) => instant,
    ).read(all);
    final unassigned = unassignedPaymentsByCustomer(
      ledger: await ledgerOf(workspaceId),
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
