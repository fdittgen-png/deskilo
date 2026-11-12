// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — whose search it is, and the reader's recent items. The recent
// items belong to one account, server and workspace: they are forgotten the
// moment any of the three changes (a sign-out, another account, a switch of
// workspace), and they hold only what a result says, never a record's
// detail.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/search_result.dart';

/// The account, server and workspace a search runs in; null signed out or
/// outside a workspace.
final searchScopeProvider = Provider<SearchScope?>((ref) {
  final account = ref.watch(currentAccountIdProvider);
  final workspace = ref.watch(activeWorkspaceIdProvider).value;
  final server = ref.watch(activeBackendProvider).value?.url;
  return account == null || workspace == null || server == null
      ? null
      : (account: account, server: server, workspace: workspace);
});

/// The most recent items kept.
const int _recentLimit = 8;

/// What the reader opened from search lately, newest first.
class SearchRecents extends Notifier<List<SearchResult>> {
  @override
  List<SearchResult> build() {
    // A new scope starts with nothing.
    ref.watch(searchScopeProvider);
    return const [];
  }

  /// [result] was opened: it goes first.
  void opened(SearchResult result) => state = [
    result,
    ...state.where((r) => r != result),
  ].take(_recentLimit).toList();
}

final searchRecentsProvider =
    NotifierProvider<SearchRecents, List<SearchResult>>(SearchRecents.new);
