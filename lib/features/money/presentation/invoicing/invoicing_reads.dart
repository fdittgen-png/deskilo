// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- one reader for the invoicing screens: the home and the
// invoice page read an invoice the same way, from the same matches,
// reminders, rules, holds, transmissions and payment events, so the page
// and the line it was opened from cannot say two different things.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../application/payment_candidates.dart';
import '../../application/receivables.dart';
import '../../domain/dunning.dart';
import '../../providers/bank_statement_providers.dart'
    show WorkspaceFeature, enabledFeaturesSyncProvider;
import '../../providers/money_providers.dart';
import '../widgets/invoice_journey_view.dart';
import 'invoicing_home.dart' show InvoicingSource;
import 'receivables_adapter.dart';

/// The reader of the invoices as receivables, now.
final invoicingReaderProvider = Provider.autoDispose<ReceivablesReader>(
  (ref) => ReceivablesReader(
    matches: ref.watch(invoiceMatchesProvider).value ?? const {},
    reminders: ref.watch(invoiceRemindersProvider).value ?? const {},
    rules: ref.watch(dunningRulesProvider).value ?? DunningRules.defaults,
    now: ref.watch(clockProvider).now(),
    // The business's calendar day, from the workspace's own context.
    dayOf: ref.watch(invoicingBusinessProvider).dayOf,
    eventFactsOf: ref.watch(invoiceEventFactsProvider),
    transmissions: ref.watch(invoiceTransmissionsProvider).value ?? const {},
    held: {...?ref.watch(dunningHoldsProvider).value?.keys},
    fold: ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.settlementFold),
  ),
);

/// The sources of the invoices' statuses that could not be read. While one
/// is here, nothing read from it is shown as read: the home names it with
/// Try again, and an invoice page offers no action.
final invoicingFailedSourcesProvider =
    Provider.autoDispose<Set<InvoicingSource>>(
      (ref) => {
        if (ref.watch(invoicesProvider).hasError) InvoicingSource.invoices,
        if (ref.watch(invoiceMatchesProvider).hasError) InvoicingSource.matches,
        if (ref.watch(invoiceRemindersProvider).hasError)
          InvoicingSource.reminders,
        if (ref.watch(dunningHoldsProvider).hasError) InvoicingSource.holds,
        if (ref.watch(invoiceTransmissionsProvider).hasError)
          InvoicingSource.transmissions,
        if (ref.watch(unassignedCreditProvider).hasError)
          InvoicingSource.credits,
      },
    );

/// Reads [source] again.
void retryInvoicingSource(WidgetRef ref, InvoicingSource source) =>
    switch (source) {
      InvoicingSource.invoices => ref.invalidate(invoicesProvider),
      InvoicingSource.matches => ref.invalidate(invoiceMatchesProvider),
      InvoicingSource.reminders => ref.invalidate(invoiceRemindersProvider),
      InvoicingSource.holds => ref.invalidate(dunningHoldsProvider),
      InvoicingSource.transmissions => ref.invalidate(
        invoiceTransmissionsProvider,
      ),
      InvoicingSource.credits => ref.invalidate(unassignedCreditProvider),
      InvoicingSource.payments || InvoicingSource.toInvoice => null,
    };

/// What each customer with an open invoice holds received and not assigned,
/// by customer and currency: the payments on their account that no invoice
/// has taken (`unmatchedPaymentsOf`, as Payments to match reads them). The
/// account is kept in the business's currency.
final unassignedCreditProvider =
    FutureProvider.autoDispose<Map<String, Map<String, int>>>((ref) async {
      final invoices = await ref.watch(invoicesProvider.future);
      final matches = await ref.watch(invoiceMatchesProvider.future);
      final currency = ref.watch(invoicingBusinessProvider).currency;
      final queries = ref.watch(memberAccountQueriesProvider);
      final consumed = {for (final m in matches.values) ?m.paymentLedgerId};
      final customers = {
        for (final r in ref.watch(invoicingReaderProvider).read(invoices))
          if (r.isOutstanding) r.customerId,
      };
      final credits = await Future.wait([
        for (final c in customers)
          queries.fetchLedger(c).then(
            (ledger) => MapEntry(
              c,
              creditMinorOf(
                unmatchedPaymentsOf(
                  memberId: c,
                  ledger: ledger,
                  consumed: consumed,
                  invoices: invoices,
                ),
              ),
            ),
          ),
      ]);
      return {
        for (final MapEntry(key: c, value: minor) in credits)
          if (minor > 0) c: {currency: minor},
      };
    });

/// The customers who hold money received and not assigned in a currency in
/// which they also owe: `holdsUnassignedMoney`, the one predicate of the
/// home's "Match" count, the reminder queue's "check first", Payments to
/// match and the customer page. Matched first, never reminded.
Set<String> holdsUnassignedOf(
  List<Receivable> receivables,
  Map<String, Map<String, int>> credit,
) => {
  for (final MapEntry(key: c, value: held) in credit.entries)
    if (holdsUnassignedMoney(
      credit: held,
      customerInvoices: receivables.where((r) => r.customerId == c),
    ))
      c,
};
