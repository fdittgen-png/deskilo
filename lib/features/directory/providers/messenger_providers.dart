// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/messenger_actions.dart';
import '../data/supabase_messenger_repository.dart';
import '../domain/messenger.dart';
import '../domain/messenger_repository.dart';

part 'messenger_providers.g.dart';

/// #1824 — the messenger on one server; '' is this one.
@riverpod
MessengerRepository messengerRepository(Ref ref, {String source = ''}) {
  // A new account is a new set of sessions: nothing of the previous
  // person's servers may answer the next person's inbox.
  ref.watch(authStateProvider);
  return SupabaseMessengerRepository(
    ref.watch(connectedInstallationsProvider),
    source,
  );
}

@riverpod
MessengerActions messengerActions(Ref ref, {String source = ''}) =>
    MessengerActions(ref.watch(messengerRepositoryProvider(source: source)));

/// Every conversation I take part in, on this server and on every
/// server I connected, as ONE list (`mergeInboxes`).
///
/// A server that does not answer is named, not fatal: its rows are
/// missing and the list says so, while the others still show.
@riverpod
Future<UnifiedInbox> unifiedInbox(Ref ref) async {
  if (ref.watch(authStateProvider).value == null) {
    return const UnifiedInbox([]);
  }
  final home = ref.watch(messengerRepositoryProvider());
  final sources = await ref.watch(connectedSourcesProvider.future);
  final repositories = <String, MessengerRepository>{
    '': home,
    for (final s in sources)
      s.endpoint.url: ref.read(
        messengerRepositoryProvider(source: s.endpoint.url),
      ),
  };
  final hosts = {for (final s in sources) s.endpoint.url: s.endpoint.host};
  final bySource = <String, List<Map<String, dynamic>>>{};
  final unavailable = <String>[];
  await Future.wait([
    for (final entry in repositories.entries)
      entry.value
          .inbox()
          .timeout(const Duration(seconds: 20))
          .then((rows) => bySource[entry.key] = rows)
          .catchError((Object e, StackTrace st) {
            TraceLogger.instance.warn(
              'messages',
              'inbox of a server failed',
              error: e,
              stackTrace: st,
            );
            unavailable.add(hosts[entry.key] ?? entry.key);
            return const <Map<String, dynamic>>[];
          }),
  ]);
  return mergeInboxes(bySource, unavailable: unavailable);
}

/// The display name of each connected server, by origin — the subtitle
/// a row carries only when it is not this server.
@riverpod
Future<Map<String, String>> serverLabels(Ref ref) async {
  final sources = await ref.watch(connectedSourcesProvider.future);
  return {for (final s in sources) s.endpoint.url: s.endpoint.host};
}

@riverpod
Future<List<ContextMessage>> contextMessages(
  Ref ref,
  MessageContextKind kind,
  String contextId, {
  String source = '',
}) => ref
    .watch(messengerActionsProvider(source: source))
    .messages(kind, contextId);

@riverpod
Future<List<MessageEvent>> messageHistory(
  Ref ref,
  MessageKind kind,
  String messageId, {
  String source = '',
}) => ref
    .watch(messengerActionsProvider(source: source))
    .history(kind, messageId);

/// Who answers an inquiry to [workspace] — shown BEFORE writing.
@riverpod
Future<List<HostRosterEntry>> hostRoster(
  Ref ref,
  String workspace, {
  String source = '',
}) => ref
    .watch(messengerRepositoryProvider(source: source))
    .hostRoster(workspace);

/// The space's Inquiries view: what outside people wrote to it.
@riverpod
Future<List<InquirySummary>> workspaceInquiries(Ref ref, String workspace) =>
    ref.watch(messengerRepositoryProvider()).workspaceInquiries(workspace);
