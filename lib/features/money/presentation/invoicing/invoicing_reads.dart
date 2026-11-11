// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- one reader for the invoicing screens: the home and the
// invoice page read an invoice the same way, from the same matches,
// reminders, rules, holds, transmissions and payment events, so the page
// and the line it was opened from cannot say two different things.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../events/providers/event_providers.dart';
import '../../application/receivables.dart';
import '../../application/unassigned_money.dart';
import '../../domain/dunning.dart';
import '../../providers/bank_statement_providers.dart'
    show WorkspaceFeature, enabledFeaturesSyncProvider;
import '../../providers/credit_move_providers.dart';
import '../../providers/money_providers.dart';
import '../widgets/invoice_journey_view.dart';
import 'invoicing_home.dart' show InvoicingSource;
import 'receivables_adapter.dart';

/// The reader of the invoices as receivables, now.
final invoicingReaderProvider = Provider.autoDispose<ReceivablesReader>(
  (ref) => ReceivablesReader(
    matches: ref.watch(invoiceMatchesProvider).value ?? const {}, // empty-ok: no receivable is built before it answered (below)
    reminders: ref.watch(invoiceRemindersProvider).value ?? const {}, // empty-ok: no receivable is built before it answered (below)
    rules: ref.watch(dunningRulesProvider).value ?? DunningRules.defaults, // empty-ok: no receivable is built before it answered (below)
    now: ref.watch(clockProvider).now(),
    // The business's calendar day, from the workspace's own context.
    dayOf: ref.watch(invoicingBusinessProvider).dayOf,
    eventFactsOf: ref.watch(invoiceEventFactsProvider),
    transmissions: ref.watch(invoiceTransmissionsProvider).value ?? const {}, // empty-ok: no receivable is built before it answered (below)
    held: {...?ref.watch(dunningHoldsProvider).value?.keys},
    fold: ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.settlementFold),
  ),
);

/// The invoices as receivables now, through [invoicingReaderProvider]; null
/// while the invoices are not read. The pages opened from the home read this,
/// never a copy taken when they opened.
/// #3680 — nor while the matches, reminders or transmissions it reads are
/// not answered: an unread match is not "unpaid", an unread reminder not
/// "never reminded". A failed one is named on the home with Try again.
final invoicingReceivablesProvider = Provider.autoDispose<List<Receivable>?>(
  (ref) {
    final statuses = [
      ref.watch(invoiceMatchesProvider),
      ref.watch(invoiceRemindersProvider),
      ref.watch(invoiceTransmissionsProvider),
      ref.watch(eventsProvider),
      // #3742 — the business's reminder rules, never their defaults.
      ref.watch(dunningRulesProvider),
    ];
    if (statuses.any((r) => !r.hasValue)) return null;
    return switch (ref.watch(invoicesProvider).value) {
      final invoices? => ref.watch(invoicingReaderProvider).read(invoices),
      null => null,
    };
  },
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
        if (ref.watch(unassignedMoneyProvider).hasError)
          InvoicingSource.credits,
        if (ref.watch(eventsProvider).hasError) InvoicingSource.declarations,
        if (ref.watch(dunningRulesProvider).hasError) InvoicingSource.rules,
      },
    );

/// #3680 — a status read is still running: nothing is counted yet (an
/// unread match is not "unpaid"). A failed one is a named source instead.
final invoicingStatusesWaitingProvider = Provider.autoDispose<bool>(
  (ref) => [
    ref.watch(invoiceMatchesProvider),
    ref.watch(invoiceRemindersProvider),
    ref.watch(invoiceTransmissionsProvider),
    ref.watch(eventsProvider),
    ref.watch(dunningRulesProvider),
  ].any((r) => !r.hasValue && !r.hasError),
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
      InvoicingSource.credits => ref.invalidate(unassignedMoneyProvider),
      InvoicingSource.declarations => ref.invalidate(eventsProvider),
      InvoicingSource.rules => ref.invalidate(dunningRulesProvider),
      InvoicingSource.payments || InvoicingSource.toInvoice => null,
    };

/// Money received and not assigned, in ONE read: the workspace's ledger
/// (one `fetchWorkspaceLedger`), the payments matches consumed (one read of
/// the junction, one of the moved credits) and the invoices; grouped per
/// customer. It depends on the invoices, the matches and the business only:
/// a reminder, a hold or a rule changes nothing here and reads nothing again.
/// The ledger rows are read through the same rule as the invoices
/// (`may_view_member_finances`, 0131): whoever sees a customer's invoice sees
/// their account. A failed read fails this one source, named on the home.
final unassignedMoneyProvider = FutureProvider.autoDispose<UnassignedMoney>((
  ref,
) async {
  final (id, currency) = ref.watch(
    invoicingBusinessProvider.select((b) => (b.id, b.currency)),
  );
  final invoiceQueries = ref.watch(invoiceQueriesProvider);
  final moves = ref.watch(creditMoveCommandsProvider);
  final accounts = ref.watch(memberAccountQueriesProvider);
  final invoices = await ref.watch(invoicesProvider.future);
  // A match writes junction rows: it refreshes this answer.
  await ref.watch(invoiceMatchesProvider.future);
  final use = await readPaymentUse(
    invoices: invoiceQueries,
    moves: moves,
    workspaceId: id,
  );
  final ledger = await accounts.fetchWorkspaceLedger(id);
  return UnassignedMoney(
    currency: currency,
    paymentsOf: unassignedPaymentsByCustomer(
      ledger: ledger,
      use: use,
      invoices: invoices,
    ),
  );
});

/// The unassigned money once it is read, or null while it is not (loading,
/// reloading or failed): unknown is not none.
UnassignedMoney? unassignedMoneyKnown(AsyncValue<UnassignedMoney> read) =>
    read.isLoading || read.hasError ? null : read.value;
