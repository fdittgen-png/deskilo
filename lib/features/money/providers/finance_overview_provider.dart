// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/finance_overview.dart';
import 'account_activity_providers.dart';

/// Me › Finances: my invoices and reminders across every workspace (0380).
final financeOverviewProvider = FutureProvider.autoDispose<FinanceOverview>((ref) {
  if (ref.watch(authStateProvider).value == null) {
    return Future.value(const FinanceOverview());
  }
  return ref.watch(accountActivityRepositoryProvider).overview();
});

/// A one-shot request to open one invoice in its own space's Money screen
/// (Me › Finances → the workspace, in the right environment). The screen
/// consumes it only when the request's space is the current one.
class InvoiceFocus extends Notifier<({String workspaceId, String invoiceId})?> {
  @override
  ({String workspaceId, String invoiceId})? build() => null;

  void request(String workspaceId, String invoiceId) =>
      state = (workspaceId: workspaceId, invoiceId: invoiceId);

  void clear() => state = null;
}

final invoiceFocusProvider =
    NotifierProvider<InvoiceFocus, ({String workspaceId, String invoiceId})?>(
      InvoiceFocus.new,
    );
