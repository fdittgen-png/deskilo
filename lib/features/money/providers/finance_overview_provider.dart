// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/account_activity.dart';
import '../domain/finance_overview.dart';
import 'account_activity_providers.dart';

part 'finance_overview_provider.g.dart';

/// Me › Finances: my invoices and reminders across every workspace (0380),
/// each read where its documents live. The personal home answers for the
/// installation the app is signed in to; when the selected workspace lives
/// on a connected installation, that host answers for its own documents on
/// the selected workspace's client, and a host that does not answer leaves
/// the others on screen and is named as unavailable rather than hiding
/// them or posing as empty.
@riverpod
Future<FinanceOverview> financeOverview(Ref ref) async {
  if (ref.watch(authStateProvider).value == null) {
    return const FinanceOverview();
  }
  final home = ref.watch(accountActivityRepositoryProvider);
  final split = ref.watch(selectedWorkspaceHostProvider);
  final selected = split == null ? null : _selectedRepository(ref);
  final mine = await home.overview();
  if (split == null) return mine;
  if (selected == null) return mine.withUnavailable(split.source);
  try {
    return mine.merge(await selected.overview());
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'own documents of the selected workspace unavailable',
      error: e,
      stackTrace: st,
    );
    return mine.withUnavailable(split.source);
  }
}

/// The selected workspace's repository — or null while its client is
/// refused (the context still resolving, the connection ended), which is a
/// host that cannot answer right now, not an error of the whole overview.
AccountActivityRepository? _selectedRepository(Ref ref) {
  try {
    return ref.watch(selectedWorkspaceAccountActivityRepositoryProvider);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'selected workspace client refused',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// A one-shot request to open one invoice in its own space's Money screen
/// (Me › Finances → the workspace, in the right environment). The screen
/// consumes it only when the request's space is the current one. Kept
/// alive: the request outlives the screen that made it.
@Riverpod(keepAlive: true)
class InvoiceFocus extends _$InvoiceFocus {
  @override
  ({String workspaceId, String invoiceId})? build() => null;

  void request(String workspaceId, String invoiceId) =>
      state = (workspaceId: workspaceId, invoiceId: invoiceId);

  void clear() => state = null;
}
