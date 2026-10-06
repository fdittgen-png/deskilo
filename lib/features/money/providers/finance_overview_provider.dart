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
