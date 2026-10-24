// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connection_outcome.dart';
import '../../../core/settings/messaging_windows.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/messenger_actions.dart';
import '../data/supabase_messenger_repository.dart';
import '../domain/inbox_composition.dart';
import '../domain/inbox_sources.dart';
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

/// #2556 C1 — Me › Messages, composed from its sources: my personal
/// conversations and groups where my account lives (the personal home,
/// `my_account_inbox_v1`) and my workspace conversations and inquiries on
/// each workspace host (`my_workspace_inbox_v1`), on this server and on
/// every server I connected. Each source is a slot with its own state
/// (reading, loaded, failed, unavailable): one that fails or cannot be
/// reached never hides the others, and the inbox shows each source as soon
/// as it answers — the personal part never waits for a workspace host.
///
/// A server without the readers (older than this build) is read the legacy
/// way (`my_inbox`); the same conversation answered twice is shown once.
/// A completion of an earlier read never lands in a newer one.
@riverpod
class MessengerInbox extends _$MessengerInbox {
  /// Which build a read belongs to: a read of an earlier one never lands.
  int _epoch = 0;

  @override
  Future<UnifiedInbox> build() async {
    final epoch = ++_epoch;
    // Every watch before the first await (provider_watch_before_await).
    final signedIn = ref.watch(authStateProvider).value != null;
    final connected = ref.watch(connectedSourcesProvider.future);
    if (!signedIn) return const UnifiedInbox([]);
    final previous = {
      for (final slot in _sources)
        slot.key: slot,
    };
    final slots = [
      for (final slot in inboxSlotsFor([
        for (final s in await connected)
          (origin: s.endpoint.url, host: s.endpoint.host),
      ]))
        // What was shown stays while it is read again: no empty flicker.
        previous[slot.key]?.rereading ?? slot,
    ];
    for (final slot in slots) {
      unawaited(_read(slot, epoch));
    }
    return composeInbox(slots);
  }

  List<InboxSlot> get _sources => switch (state.value) {
    ComposedInbox(:final sources) => sources,
    _ => const [],
  };

  /// Reads [slot] once more (its Try again).
  void retry(String key) {
    final slot = _slot(key);
    if (slot == null) return;
    unawaited(_put(slot.rereading, _epoch, settled: false));
    unawaited(_read(slot.rereading, _epoch));
  }

  /// The next page of every source that has more.
  void more() {
    for (final slot in _sources) {
      if (!slot.hasMore || slot.loadingMore || slot.next == null) continue;
      unawaited(_put(slot.readingMore, _epoch, settled: false));
      unawaited(_read(slot.readingMore, _epoch, more: true));
    }
  }

  InboxSlot? _slot(String key) => _sources
      .where((s) => s.key == key)
      .firstOrNull;

  Future<void> _read(InboxSlot slot, int epoch, {bool more = false}) async {
    final repository = ref.read(
      messengerRepositoryProvider(source: slot.source),
    );
    InboxSlot next;
    try {
      final page = await repository
          .inboxPage(slot.role, before: more ? slot.next : null)
          .timeout(const Duration(seconds: 20));
      next = more ? slot.appended(page) : slot.firstPage(page);
    } on InboxSourceRefused catch (e, st) {
      next = switch (e.failure) {
        InboxSourceFailure.unsupported =>
          await _legacy(repository, slot),
        // The server the app is signed in to must be my personal home; any
        // other server simply does not play a role it refuses.
        InboxSourceFailure.wrongRole =>
          slot.source.isEmpty && slot.role == InboxSourceRole.personalHome
              ? slot.unavailable(e)
              : slot.absent,
        _ => slot.failed(e),
      };
      if (next.state != InboxSlotState.loaded &&
          next.state != InboxSlotState.absent) {
        TraceLogger.instance.warn(
          'messages',
          'an inbox source refused',
          error: e.failure.name,
          stackTrace: st,
        );
      }
    } on ConnectionFailure catch (e, st) {
      TraceLogger.instance.warn(
        'messages',
        'an inbox source cannot be reached',
        error: e.reason.name,
        stackTrace: st,
      );
      // Only a lost transport is worth trying again as it is; a refused or
      // changed sign-in is the connection's to repair.
      next = e.reason == ConnectionFailureReason.unavailable
          ? slot.failed(e)
          : slot.unavailable(e);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'messages',
        'an inbox source failed',
        error: e,
        stackTrace: st,
      );
      next = slot.failed(e);
    }
    await _put(next, epoch, settled: true);
  }

  /// A server older than the readers: its whole legacy inbox, once.
  Future<InboxSlot> _legacy(MessengerRepository repository, InboxSlot slot) async {
    try {
      return slot.legacyRows(
        await repository.inbox().timeout(const Duration(seconds: 20)),
      );
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'messages',
        'a legacy inbox failed',
        error: e,
        stackTrace: st,
      );
      return slot.failed(e);
    }
  }

  /// [slot] in place of its earlier self — never into a newer read: a
  /// rebuild unmounts this ref, and a slot read again since is replaced
  /// only by that read's own completion.
  Future<void> _put(InboxSlot slot, int epoch, {required bool settled}) async {
    if (settled) {
      if (!ref.mounted) return;
      // The build that started this read hands its value over first.
      await future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    }
    if (!ref.mounted || epoch != _epoch) return;
    final current = state.value;
    if (current is! ComposedInbox) return;
    state = AsyncData(composeInbox([
      for (final s in current.sources)
        if (s.key == slot.key) slot else s,
    ]));
  }
}

/// While watched, re-reads [messengerInboxProvider] every inbox poll, so an
/// unread badge stays current before the inbox itself is open (the open
/// inbox polls on its own). Answers the period it refreshes at.
@riverpod
Duration inboxBadgeRefresh(Ref ref) {
  final poll = ref.read(messagingWindowsProvider).inboxPoll;
  final timer = Timer.periodic(
    poll,
    (_) => ref.invalidate(messengerInboxProvider),
  );
  ref.onDispose(timer.cancel);
  return poll;
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

/// #2216 — the signed-in account, which a group mention names.
@riverpod
String? myAccountId(Ref ref) => ref.watch(authStateProvider).value;
