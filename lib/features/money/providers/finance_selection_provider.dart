// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — the invoices I select on My finances, for this account. What
// the bar shows is the selection as the overview reads it now: an invoice
// paid, declared or no longer payable meanwhile leaves it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_source.dart';
import '../application/finance_selection_commands.dart';
import '../domain/finance_overview.dart';
import '../domain/finance_selection.dart';
import '../domain/payment_request_ids.dart';
import 'finance_overview_provider.dart';
import 'money_queries_providers.dart';

part 'finance_selection_provider.g.dart';

@riverpod
class FinanceSelectionController extends _$FinanceSelectionController {
  @override
  FinanceSelection build() {
    // CACHE-01 (#2557): a selection is this account's.
    ref.watch(sessionStateProvider.select((s) => s.value));
    return FinanceSelection.none;
  }

  void toggle(FinanceInvoice invoice) => state = state.toggled(invoice);

  void remove(Iterable<FinanceInvoice> invoices) =>
      state = state.without(invoices);

  void clear() => state = FinanceSelection.none;
}

/// The selection with each invoice as the overview reads it now; one no
/// longer selectable (paid, declared, in a payment) is left out.
@riverpod
FinanceSelection financeSelection(Ref ref) {
  final chosen = ref.watch(financeSelectionControllerProvider);
  final overview = ref.watch(financeOverviewProvider).value;
  if (chosen.isEmpty || overview == null) return chosen;
  return FinanceSelection([
    for (final c in chosen.invoices)
      for (final i in overview.invoices)
        if (i.workspaceId == c.workspaceId &&
            i.id == c.id &&
            FinanceSelection.selectable(i))
          i,
  ]);
}

/// Enters a business as Open does. Nothing by default; the composition root
/// selects the workspace (`financeWorkspaceEntryFromApp`, lib/app), where
/// money and the workspace meet.
@Riverpod(keepAlive: true)
FinanceWorkspaceEntry financeWorkspaceEntry(Ref ref) =>
    (_) async => null;

/// My finances' commands on a selection and a payment being processed.
/// Kept alive: a command outlives the tap that started it. It reads kept-
/// alive providers only; the selection is the page's, and the page takes
/// out of it what a command recorded.
@Riverpod(keepAlive: true)
FinanceSelectionCommands financeSelectionCommands(Ref ref) =>
    FinanceSelectionCommands(
      enter: ref.watch(financeWorkspaceEntryProvider),
      commands: () => ref.read(memberAccountCommandsProvider),
    );

/// #3556 — the request ids of my payments, one set per account, shared by
/// My finances and the Money screen: a retry after a lost answer is the
/// same request, so the payment flow gives its checkout back instead of a
/// second payment (0797's replay).
@Riverpod(keepAlive: true)
PaymentRequestIds paymentRequestIds(Ref ref) {
  ref.watch(sessionStateProvider.select((s) => s.value));
  return PaymentRequestIds();
}
