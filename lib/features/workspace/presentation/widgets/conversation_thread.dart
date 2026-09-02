// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member_note.dart';
import '../../domain/member_note_refs.dart';
import '../../domain/workspace_feature.dart';
import '../../../members/presentation/member_profile_link.dart';
import '../../providers/conversation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'conversation_bubble.dart';
import 'group_info_sheet.dart';
import 'member_note_composer.dart';

/// A conversation, by id (#687) — the thread behind a row of the
/// messaging centre, for a direct exchange or a group alike.
///
/// #821 — with `messagesHub` on the thread is a PAGE (`/conversation/:id`):
/// full height, a back gesture, a deep link. Off, the 72 % sheet stays.
Future<void> showConversationThread(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  String? seedBody,
}) async {
  // Read BEFORE the sheet opens, so the badge and the row weight have
  // already settled by the time it closes.
  await runGuarded(
    context,
    domain: 'workspace',
    message: 'mark conversation read failed',
    // Silent: failing to clear an unread badge must never block reading
    // the messages behind it.
    errorText: '',
    action: () =>
        ref.read(workspaceRepositoryProvider).markConversationRead(
              conversationId,
            ),
  );
  if (!context.mounted) return;
  final hub = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.messagesHub);
  if (hub) {
    if (seedBody != null && seedBody.trim().isNotEmpty) {
      // The seed travels through the draft store, not the URL.
      ref.read(conversationDraftsProvider.notifier).set(conversationId, seedBody);
    }
    await context.push('/conversation/$conversationId');
    return;
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ConversationThread(
      conversationId: conversationId,
      seedBody: seedBody,
    ),
  );
}

/// #821 — the thread as a route: its own Scaffold, the header in the
/// app bar, the composer pinned to the bottom above the keyboard.
class ConversationThreadPage extends ConsumerWidget {
  const ConversationThreadPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        key: const ValueKey('conversation-page'),
        body: SafeArea(
          child: ConversationThread(
            conversationId: conversationId,
            asPage: true,
          ),
        ),
      );
}

class ConversationThread extends ConsumerStatefulWidget {
  const ConversationThread({
    super.key,
    required this.conversationId,
    this.seedBody,
    this.asPage = false,
  });

  final String conversationId;

  /// #622 — pre-seeds the composer with the reference the message is
  /// about, carried over unchanged from the old sheet.
  final String? seedBody;

  /// #821 — rendered as a page (full height, back button) rather than
  /// the 72 % sheet.
  final bool asPage;

  @override
  ConsumerState<ConversationThread> createState() => _ConversationThreadState();
}

class _ConversationThreadState extends ConsumerState<ConversationThread> {
  /// #798 — the message the next send will quote, set by swiping a
  /// bubble right and cleared by sending or by the chip's close button.
  ({String id, String preview})? _quoted;

  /// #821 — pages of history older than the provider's newest page,
  /// oldest first, loaded on demand.
  final List<MemberNote> _earlier = [];
  bool _loadingEarlier = false;
  bool _noMoreEarlier = false;

  /// One key per bubble so a tapped quote can scroll to its original.
  final Map<String, GlobalKey> _bubbleKeys = {};

  bool get _hub => ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.messagesHub);

  GlobalKey _keyFor(String noteId) =>
      _bubbleKeys.putIfAbsent(noteId, GlobalKey.new);

  Future<void> _loadEarlier(List<MemberNote> newest) async {
    if (_loadingEarlier || _noMoreEarlier) return;
    final oldest = [..._earlier, ...newest].firstOrNull;
    if (oldest == null) return;
    setState(() => _loadingEarlier = true);
    try {
      final page = await ref
          .read(workspaceRepositoryProvider)
          .fetchConversationMessages(widget.conversationId,
              before: oldest.createdAt);
      if (!mounted) return;
      setState(() {
        _earlier.insertAll(0, page);
        _noMoreEarlier = page.isEmpty;
        _loadingEarlier = false;
      });
    } catch (e, st) {
      TraceLogger.instance.error('messaging', 'load earlier failed',
          error: e, stackTrace: st);
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  void _scrollToQuote(String noteId) {
    final ctx = _keyFor(noteId).currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = widget.conversationId;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final newest =
        ref.watch(conversationMessagesProvider(conversationId)).value ??
            const <MemberNote>[];
    final hub = _hub;
    // #821 — a message that lands while the thread is OPEN is read as it
    // lands: the watermark moves again, so the badge behind never counts
    // what is on screen.
    ref.listen(conversationMessagesProvider(conversationId), (prev, next) {
      final before = prev?.value?.length ?? 0;
      final after = next.value?.length ?? 0;
      if (after > before && before > 0) {
        ref
            .read(workspaceRepositoryProvider)
            .markConversationRead(conversationId)
            .then((_) => ref.invalidate(conversationsProvider))
            .catchError((Object e, StackTrace st) {
          TraceLogger.instance.warn('messaging', 're-mark read failed',
              error: e, stackTrace: st);
        });
      }
    });
    final conversation = (ref.watch(conversationsProvider).value ?? const [])
        .where((c) => c.id == conversationId)
        .firstOrNull;

    final title = conversation == null
        ? ''
        : conversation.isGroup
            ? (conversation.title ?? (l10n?.conversationGroup ?? 'Group'))
            : (names[conversation.otherMemberId] ??
                (l10n?.conversationUnknownMember ?? 'Member'));
    final messages = [..._earlier, ...newest];
    final canLoadEarlier = hub &&
        !_noMoreEarlier &&
        newest.length >= 200 - 1 &&
        !_loadingEarlier;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        widget.asPage ? AppSpacing.xs : AppSpacing.xl,
        widget.asPage ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(children: [
        if (widget.asPage)
          IconButton(
            key: const ValueKey('conversation-back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        Expanded(
          // The HEADER is the way into the roster — WhatsApp's idiom, and
          // the one place people look for "who is in this".
          child: InkWell(
            key: const ValueKey('conversation-header'),
            onTap: conversation == null
                ? null
                : conversation.isGroup
                    ? () => showGroupInfoSheet(
                          context,
                          ref,
                          conversation: conversation,
                        )
                    : (conversation.otherMemberId == null
                        ? null
                        : () => openMemberProfile(
                              context,
                              ref,
                              memberId: conversation.otherMemberId!,
                            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (conversation?.muted ?? false) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.notifications_off_outlined,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ]),
                if (!(conversation?.isGroup ?? true))
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      l10n?.conversationSeeProfile ?? 'See profile',
                      style: theme.textTheme.bodySmall,
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: theme.textTheme.bodySmall?.color),
                  ]),
                if (conversation?.isGroup ?? false)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      l10n?.conversationMemberCount(
                            conversation!.participantCount,
                          ) ??
                          '${conversation!.participantCount} members',
                      style: theme.textTheme.bodySmall,
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: theme.textTheme.bodySmall?.color),
                  ]),
              ],
            ),
          ),
        ),
        if (!widget.asPage)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
      ]),
    );

    final list = messages.isEmpty
        ? Center(
            child: Text(
              l10n?.conversationEmpty ?? 'No messages yet — say hello!',
              style: theme.textTheme.bodySmall,
            ),
          )
        : ListView.builder(
            // Reversed so the newest message is in view and stays there
            // when the keyboard opens.
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            itemCount: messages.length + (canLoadEarlier || _loadingEarlier ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length) {
                return Center(
                  child: _loadingEarlier
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton.icon(
                          key: const ValueKey('conversation-load-earlier'),
                          onPressed: () => _loadEarlier(newest),
                          icon: const Icon(Icons.history, size: 18),
                          label: Text(l10n?.conversationLoadEarlier ??
                              'Load earlier messages'),
                        ),
                );
              }
              final i = messages.length - 1 - index;
              final note = messages[i];
              final previous = i > 0 ? messages[i - 1] : null;
              final bubble = ConversationBubble(
                key: hub ? _keyFor(note.id) : null,
                note: note,
                mine: note.fromMemberId == me?.id,
                timeOnly: hub,
                onQuoteTap: hub ? _scrollToQuote : null,
                onQuote: (quoted) => setState(() {
                  _quoted = (
                    id: quoted.id,
                    preview: notePreview(quoted.body, max: 80),
                  );
                }),
                // A GROUP bubble names its sender; a direct one does not.
                senderName: (conversation?.isGroup ?? false) &&
                        note.fromMemberId != me?.id
                    ? names[note.fromMemberId]
                    : null,
              );
              // #821 — a date separator where the day changes, so the
              // bubbles can carry the time alone.
              if (!hub || (previous != null && _sameDay(previous, note))) {
                return bubble;
              }
              return Column(children: [
                _DaySeparator(
                  day: note.createdAt.toLocal(),
                  today: ref.read(clockProvider).now(),
                ),
                bubble,
              ]);
            },
          );

    final composer = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: MemberNoteComposer(
        autofocus: false,
        seedBody: hub
            ? (ref.read(conversationDraftsProvider)[conversationId] ??
                widget.seedBody)
            : widget.seedBody,
        onChanged: hub
            ? (text) => ref
                .read(conversationDraftsProvider.notifier)
                .set(conversationId, text)
            : null,
        compact: hub,
        quoted: _quoted,
        onCancelQuote: () => setState(() => _quoted = null),
        onSend: (body) => _send(context, ref, body),
      ),
    );

    final body = Column(children: [
      header,
      Expanded(child: list),
      composer,
    ]);

    if (widget.asPage) {
      return SizedBox(key: const ValueKey('conversation-thread'), child: body);
    }
    // This context lives in the SHEET route, above the Scaffold, so it
    // sees the real keyboard inset — the composer lifts and the thread
    // shrinks with it rather than being buried.
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          key: const ValueKey('conversation-thread'),
          height: (media.size.height - media.viewInsets.bottom) * 0.72,
          child: body,
        ),
      ),
    );
  }

  bool _sameDay(MemberNote a, MemberNote b) {
    final x = a.createdAt.toLocal();
    final y = b.createdAt.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Future<bool> _send(BuildContext context, WidgetRef ref, String body) async {
    final conversationId = widget.conversationId;
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'send conversation message failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .sendConversationMessage(conversationId, body),
    );
    if (!ok) return false;
    if (mounted) setState(() => _quoted = null);
    ref.read(conversationDraftsProvider.notifier).set(conversationId, '');
    // The thread shows it land, so no snack — but the LIST behind still
    // holds the old preview and order.
    ref
      ..invalidate(conversationMessagesProvider(conversationId))
      ..invalidate(conversationsProvider);
    return true;
  }
}

/// #821 — "Today", "Yesterday" or the date, centred between the days.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day, required this.today});

  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    final label = diff == 0
        ? (l10n?.conversationToday ?? 'Today')
        : diff == -1
            ? (l10n?.conversationYesterday ?? 'Yesterday')
            : DateFormat.yMMMEd(Localizations.maybeLocaleOf(context)?.toString())
                .format(day);
    return Center(
      child: Container(
        key: ValueKey('conversation-day-${d.year}-${d.month}-${d.day}'),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.xlAll,
        ),
        child: Text(label, style: theme.textTheme.labelSmall),
      ),
    );
  }
}
