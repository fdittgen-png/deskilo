// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../money/domain/payment_method.dart';
import '../../../money/presentation/payment_method_labels.dart';
import '../../domain/event_decision.dart';
import '../../domain/notification_feed.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../../../workspace/presentation/screens/inbox_screen.dart';
import '../../providers/event_providers.dart';
import '../../providers/notification_filter_providers.dart';
import '../event_labels.dart';
import '../event_lines.dart';
import '../feed_notes.dart';
import '../widgets/pending_decisions_section.dart';
import '../widgets/validation_trail.dart';
import '../widgets/note_row.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ui/edge_fade_scroll.dart';

/// The Events space (spec §8.1): pending confirmations pinned on top,
/// ONE mixed date-sorted feed below (#581) — messages and workspace
/// events interleaved chronologically, filtered by category × read
/// state, and the filter choice persists across app restarts. Server
/// RLS scopes workers to their own events and admins to everything.
/// Since #230 it is no longer a shell tab but a pushed route behind the
/// app-bar bell, so it carries its own Scaffold and app bar.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the notification surface reads the messages (#464): the
    // unread counters on the bell and the app icon clear here. The
    // events-seen stamp advances too (#581) — but the PREVIOUS stamp
    // keeps serving this visit, so "new" rows do not vanish mid-look.
    // #821 — only when this face is actually SHOWING. The inbox keeps
    // every face alive in an IndexedStack, so this state is built the
    // moment the inbox opens on Chats — marking seen here unconditionally
    // cleared the alerts badge for alerts nobody had looked at.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfShowing());
  }

  bool _seenThisShowing = false;

  /// Called from build: the face marks seen the first frame it SHOWS.
  void _followTab() => ref.listen(inboxTabControllerProvider, (_, _) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _markSeenIfShowing());
      });

  void _markSeenIfShowing() {
    if (!mounted) return;
    if (ref.read(inboxTabControllerProvider) != InboxTab.alerts) {
      _seenThisShowing = false;
      return;
    }
    if (_seenThisShowing) return;
    _seenThisShowing = true;
    ref.read(unreadNoteCountProvider.notifier).markAllSeen();
    ref.read(eventsSeenCutoffProvider.notifier).markOpened();
  }


  String _line(
    AppLocalizations? l10n,
    WorkspaceEvent event,
    Map<String, String> names,
    Map<String, String> targets,
    MoneyFormat currency,
  ) =>
      eventLine(l10n, event, names, targets, currency);

  /// #598 — the symbol of a grouping axis; it fronts both the chip and
  /// every group header (where tapping it ungroups).
  IconData _groupingIcon(FeedGrouping grouping) {
    return switch (grouping) {
      FeedGrouping.type => Icons.category_outlined,
      FeedGrouping.date => Icons.today_outlined,
      FeedGrouping.user => Icons.person_outline,
      FeedGrouping.none => Icons.notes,
    };
  }

  String _groupingLabel(AppLocalizations? l10n, FeedGrouping grouping) {
    return switch (grouping) {
      FeedGrouping.type => l10n?.notifGroupByType ?? 'Type',
      FeedGrouping.date => l10n?.notifGroupByDate ?? 'Date',
      FeedGrouping.user => l10n?.notifGroupByUser ?? 'Member',
      FeedGrouping.none => '',
    };
  }

  String _groupTitle(
    AppLocalizations? l10n,
    FeedGrouping grouping,
    FeedGroup group,
    Map<String, String> names,
  ) {
    return switch (grouping) {
      FeedGrouping.type =>
        notificationCategoryLabel(l10n, group.key as NotificationCategory),
      FeedGrouping.date =>
        DateFormat.yMMMEd().format(group.key as DateTime),
      FeedGrouping.user => names[group.key] ?? '',
      FeedGrouping.none => '',
    };
  }

  /// One group header (#598): the grouping symbol — one tap on it flips
  /// straight back to the flat list — followed by the group's name.
  Widget _groupHeader(
    BuildContext context,
    AppLocalizations? l10n,
    FeedGrouping grouping,
    FeedGroup group,
    Map<String, String> names,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            key: ValueKey('notif-ungroup-${group.id}'),
            tooltip: l10n?.notifUngroup ?? 'Ungroup',
            onPressed: () => ref
                .read(notificationFilterProvider.notifier)
                .setGrouping(FeedGrouping.none),
            icon: Icon(_groupingIcon(grouping), size: 20),
          ),
          Expanded(
            child: Text(
              _groupTitle(l10n, grouping, group, names),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(WorkspaceEvent event) {
    return switch (event.type) {
      EventType.reservation => event.action == EventAction.cancelled
          ? Icons.event_busy
          : Icons.event_seat,
      EventType.payment => Icons.payments_outlined,
      EventType.expense => Icons.receipt_long_outlined,
      EventType.adjustment => Icons.tune,
      EventType.serviceCharge => Icons.room_service_outlined,
      EventType.quota => Icons.hourglass_top_outlined,
      EventType.memberJoin => Icons.person_add_alt,
      EventType.spaceReservation => Icons.meeting_room_outlined,
      EventType.roleChange => Icons.admin_panel_settings_outlined,
      EventType.invoicePayment => Icons.price_check_outlined,
      EventType.reservationDelete => Icons.delete_outline,
      EventType.invoiceWriteoff => Icons.money_off_csred_outlined,
      EventType.invoiceReminder => Icons.notification_important_outlined,
      EventType.priceNegotiation => Icons.handshake_outlined,
      EventType.expenseSchedule => Icons.event_repeat_outlined,
      EventType.expenseRepartition => Icons.call_split,
    EventType.usageCorrection => Icons.timelapse_outlined,
    EventType.usageRecordDelete => Icons.playlist_remove_outlined,
    EventType.paymentTermsChange => Icons.request_quote_outlined,
    EventType.invoiceIssue => Icons.receipt_long_outlined,
    EventType.invoiceVoid => Icons.cancel_presentation_outlined,
    EventType.refund => Icons.undo_outlined,
    EventType.memberStatusChange => Icons.person_off_outlined,
    EventType.subscriptionChange => Icons.percent_outlined,
    EventType.matrixChange => Icons.admin_panel_settings_outlined,
    // #1088 — a type this build does not know gets the neutral mark.
    EventType.unknown => Icons.info_outline,
    };
  }

  String? _quorumProgress(
    AppLocalizations? l10n,
    WorkspaceEvent event,
    List<EventDecision> decisions,
    List<ValidationPolicy> policies,
  ) =>
      eventQuorumProgress(l10n, event, decisions, policies);

  /// #154 — the localized payment-method line for a payment event, or
  /// null when the payload carries no known method (pre-#154 events, ''
  /// = not specified, or a wire name from a newer app version).
  String? _methodLine(AppLocalizations? l10n, WorkspaceEvent event) {
    if (event.type != EventType.payment) return null;
    final method =
        PaymentMethod.fromWire(event.payload['method'] as String?);
    if (method == null) return null;
    return paymentMethodLabel(l10n, method);
  }

  /// #636 — an auto-settled deletion (#629) is a rule firing, not a
  /// colleague agreeing, and the feed has to say which one happened.
  /// The server stamps `payload.auto_validated` on exactly those events;
  /// a peer-reviewed deletion carries no such key and renders as before.
  String? _autoValidatedNote(AppLocalizations? l10n, WorkspaceEvent event) {
    if (event.payload['auto_validated'] != true) return null;
    return l10n?.eventAutoValidated ?? 'Auto-validated';
  }

  String _when(WorkspaceEvent event) =>
      eventWhen(event, ref.watch(appFormatProvider));

  @override
  Widget build(BuildContext context) {
    _followTab();
    final l10n = AppLocalizations.of(context);
    final eventsAsync = ref.watch(eventsProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final myMember = ref.watch(myMemberProvider).value;
    final decisions = ref.watch(eventDecisionsProvider).value ??
        const <String, List<EventDecision>>{};
    final policies =
        ref.watch(validationPoliciesProvider).value ?? const [];
    final currency = moneyFormat(ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR');
    // #687 — MESSAGES ARE NOT NOTIFICATIONS ANY MORE.
    //
    // They were mixed into this feed because there was nowhere else for
    // them. Now there is a messaging centre, and a message in two places
    // is a message you can mark read in one and still see unread in the
    // other. It also counted what YOU sent, which is an inbox reporting
    // your own outbox.
    //
    // #687 — BROADCASTS STAY, the direct exchange left. A broadcast is a
    // fan-out to whoever is an admin at READ time: no recipient, no
    // thread, nowhere in the messaging centre to live. Emptying this
    // list outright would have made it vanish from the app.
    final unreadIds =
        ref.watch(unreadNoteIdsProvider).value ?? const <String>{};
    final notes = broadcastsForFeed(ref);
    // #581 — the persisted filter and the previous-visit stamp that
    // "new" events are measured against.
    final filter = ref.watch(notificationFilterProvider).value ??
        const NotificationFilterState();
    final seenBefore = ref.watch(eventsSeenCutoffProvider).value;
    final unreadOnly = filter.read == ReadFilter.unread;
    // #598 — the regrouping axis; the flag OFF forces the flat list
    // even when an older persisted choice still says otherwise.
    final groupingOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.notificationGrouping);
    final grouping = groupingOn ? filter.grouping : FeedGrouping.none;

    final body = switch (eventsAsync) {
      AsyncData(value: final all) => Builder(
          builder: (context) {
            final pendingForMe = all.where((e) {
              if (myMember == null) return false;
              final policy = policyFor(e.type.dbName, policies);
              return e.isDecidedBy(
                myMember,
                policy: policy,
                alreadyDecided: (decisions[e.id] ?? const [])
                    .any((d) => d.memberId == myMember.id),
              );
            }).toList();
            final feed = buildNotificationFeed(
              events: all
                  .where((e) => !pendingForMe.contains(e))
                  .toList(),
              notes: notes,
              unreadNoteIds: unreadIds,
              eventsSeenBefore: seenBefore,
              filter: filter,
            );
            if (all.isEmpty && notes.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => invalidateBookingData(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: EmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: l10n?.eventsEmpty ?? 'No events yet.',
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => invalidateBookingData(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                // #546 — the bell's unread filter narrows the whole
                // screen to what is new; the pending decisions step
                // aside while it is on.
                if (!unreadOnly && pendingForMe.isNotEmpty) ...[
                  // #1306 — the same section the calendar shows when the
                  // bell is switched off.
                  PendingDecisionsSection(pending: pendingForMe),
                  const Divider(),
                ],
                // #581 — ONE filter line: categories × read state, all
                // persisted. Empty category selection = everything.
                EdgeFadeScroll(
                  padding: AppSpacing.mdH,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(l10n?.eventsFilterAll ?? 'All'),
                        selected: filter.categories.isEmpty,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => ref
                            .read(notificationFilterProvider.notifier)
                            .clearCategories(),
                      ),
                      for (final category
                          in NotificationCategory.values) ...[
                        const SizedBox(width: 8),
                        FilterChip(
                          key: ValueKey('notif-cat-${category.wire}'),
                          label: Text(notificationCategoryLabel(l10n, category)),
                          selected:
                              filter.categories.contains(category),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => ref
                              .read(notificationFilterProvider.notifier)
                              .toggleCategory(category),
                        ),
                      ],
                    ],
                  ),
                ),
                // Read-state line, kept OFF the category line so both
                // stay reachable without scrolling (#539/#546 — the
                // keys predate the mixed feed).
                Padding(
                  padding: AppSpacing.mdH,
                  child: Row(
                    children: [
                      // #1184 — the same overflow strategy as the
                      // category line above: the chips scroll and say
                      // so, while the sort button keeps its place at
                      // the end. As a plain Row this line ran off the
                      // right of a narrow phone at a large text scale,
                      // and a four-digit unread count did it at any
                      // scale.
                      Expanded(
                        child: EdgeFadeScroll(
                          child: Row(
                            children: [
                      FilterChip(
                        key: const ValueKey('notes-filter-unread'),
                        label: Text(
                          '${l10n?.notesFilterUnread ?? 'Unread'}'
                          '${unreadIds.isEmpty ? '' : ' (${unreadIds.length})'}',
                        ),
                        selected: unreadOnly,
                        visualDensity: VisualDensity.compact,
                        onSelected: (value) => ref
                            .read(notificationFilterProvider.notifier)
                            .setRead(
                              value ? ReadFilter.unread : ReadFilter.all,
                            ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        key: const ValueKey('notes-filter-read'),
                        label:
                            Text(l10n?.notesFilterRead ?? 'Read'),
                        selected: filter.read == ReadFilter.read,
                        visualDensity: VisualDensity.compact,
                        onSelected: (value) => ref
                            .read(notificationFilterProvider.notifier)
                            .setRead(
                              value ? ReadFilter.read : ReadFilter.all,
                            ),
                      ),
                            ],
                          ),
                        ),
                      ),
                      // #581 — flip the date sort; the choice persists
                      // like the rest of the filter. It sat in an app
                      // bar this screen no longer has (#702), and it
                      // reads better here anyway: every other control
                      // that shapes the list is on these two lines.
                      IconButton(
                        key: const ValueKey('events-sort-toggle'),
                        tooltip: l10n?.notifSortByDate ?? 'Sort by date',
                        onPressed: () => ref
                            .read(notificationFilterProvider.notifier)
                            .toggleSort(),
                        icon: Icon(
                          filter.sort == FeedSort.newestFirst
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                        ),
                      ),
                    ],
                  ),
                ),
                // #598 — the regrouping line: fold the feed by type,
                // day or member. Tapping the selected chip — or the
                // symbol on any group header — returns to flat.
                if (groupingOn)
                  EdgeFadeScroll(
                    padding: AppSpacing.mdH,
                    child: Row(
                      children: [
                        Text(
                          l10n?.notifGroupBy ?? 'Group by',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        for (final axis in const [
                          FeedGrouping.type,
                          FeedGrouping.date,
                          FeedGrouping.user,
                        ]) ...[
                          const SizedBox(width: 8),
                          FilterChip(
                            key: ValueKey('notif-group-${axis.name}'),
                            // #1191 — a selected chip draws its OWN
                            // tick, and it lands on the avatar: the
                            // group-by glyph under a checkmark reads
                            // as a dark smudge. The avatar IS the
                            // state here.
                            showCheckmark: false,
                            avatar: Icon(_groupingIcon(axis), size: 18),
                            label: Text(_groupingLabel(l10n, axis)),
                            selected: filter.grouping == axis,
                            visualDensity: VisualDensity.compact,
                            onSelected: (value) => ref
                                .read(
                                    notificationFilterProvider.notifier)
                                .setGrouping(
                                  value ? axis : FeedGrouping.none,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // The MIXED feed (#581): notes and events interleaved,
                // date-sorted under the user's direction of choice —
                // optionally folded into groups (#598).
                for (final group in groupFeed(feed, grouping)) ...[
                  if (grouping != FeedGrouping.none)
                    _groupHeader(context, l10n, grouping, group, names),
                for (final item in group.items)
                  switch (item) {
                    NoteFeedItem(:final note, :final unread) => NoteRow(
                        key: ValueKey('note-${note.id}'),
                        note: note,
                        names: names,
                        myMemberId: myMember?.id,
                        unread: unread,
                      ),
                    EventFeedItem(:final event, :final unread) =>
                      ListTile(
                        leading: Icon(_icon(event)),
                        title: Text(
                          _line(l10n, event, names, targets, currency),
                          style: unread
                              ? const TextStyle(
                                  fontWeight: FontWeight.w600,
                                )
                              : null,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // #636 — the same `· suffix` idiom the
                            // pending card uses for quorum progress:
                            // present only when the server flagged the
                            // event as self-settled.
                            Text(
                              switch (_autoValidatedNote(l10n, event)) {
                                final note? => '${_when(event)} · $note',
                                null => _when(event),
                              },
                            ),
                            // #154 — how the money moved; absent /
                            // pre-#154 payloads render no method line.
                            if (_methodLine(l10n, event)
                                case final method?)
                              Text(method),
                            ValidationTrail(
                              decisions: decisions[event.id] ?? const [],
                              names: names,
                              sequential:
                                  policyFor(event.type.dbName, policies)
                                      .sequential,
                            ),
                            // Quorum progress stays neutral: it only
                            // renders while the event is pending, i.e.
                            // before the quorum is satisfied (#196).
                            if (_quorumProgress(
                              l10n,
                              event,
                              decisions[event.id] ?? const [],
                              policies,
                            ) case final progress?)
                              Text(progress),
                          ],
                        ),
                        // #196 — semantic outcome trailing: pending
                        // waits, applied/confirmed succeeded (green),
                        // rejected failed (red). Expired events carry no
                        // outcome mark.
                        trailing: switch (event.status) {
                          EventStatus.pending =>
                            const Icon(Icons.hourglass_top, size: 18),
                          EventStatus.applied ||
                          EventStatus.confirmed =>
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: AppStatusColors.successOf(
                                Theme.of(context).brightness,
                              ),
                            ),
                          EventStatus.rejected => Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color:
                                  Theme.of(context).colorScheme.error,
                            ),
                          // #1088 — an unknown status carries no
                          // outcome claim, like an expired one.
                          EventStatus.expired ||
                          EventStatus.unknown =>
                            null,
                        },
                      ),
                  },
                ],
                if (feed.isEmpty)
                  Padding(
                    padding: AppSpacing.lgAll,
                    child: Text(
                      l10n?.notesFilterEmpty ??
                          'No unread messages — all caught up.',
                      key: const ValueKey('notes-filter-empty'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      AsyncError() => Center(
          child: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      _ => const LoadingView(),
    };
    // NO SCAFFOLD, no app bar of its own (#702): the feed is one face
    // of the inbox, which owns the bar above it — the same arrangement
    // the member directory has had since #230.
    //
    // Its two app-bar actions went with it. The sort toggle moved down
    // to the read-state line, beside the chips it belongs with; the
    // unread action was a DUPLICATE of the chip sitting inches away —
    // it existed because the bell used to land you here with the chips
    // possibly scrolled off, and the bell is gone.
    //
    // #606 — the feed's contextual how-to; gated inside the widget.
    return Column(children: [
      const HelpHint(HelpHintId.events),
      Expanded(child: body),
    ]);
  }
}
