// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/controls_feed_body.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/domain/payment_method.dart';
import '../../../money/presentation/payment_method_labels.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/event_decision.dart';
import '../../domain/notification_feed.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../../providers/attention_providers.dart';
import '../../providers/event_providers.dart';
import '../../providers/notification_filter_providers.dart';
import '../event_labels.dart';
import '../event_lines.dart';
import '../feed_notes.dart';
import '../widgets/events_filter_bar.dart';
import '../widgets/note_row.dart';
import '../widgets/pending_decisions_section.dart';
import '../widgets/validation_trail.dart';

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
    // Only a visible Alerts surface acknowledges its displayed categories.
    // Inactive navigation branches stay mounted with their ticker disabled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfShowing());
  }

  final _seenThisShowing = <NotificationCategory>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfShowing());
  }

  /// Called from build: the face marks seen the first frame it SHOWS.
  void _followTab() {
    ref.listen(attentionScopeProvider, (_, _) {
      _seenThisShowing.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfShowing());
    });
    ref.listen(eventsProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfShowing());
    });
    ref.listen(notificationFilterProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfShowing());
    });
  }

  void _markSeenIfShowing() {
    if (!mounted) return;
    if (!TickerMode.valuesOf(context).enabled) {
      _seenThisShowing.clear();
      return;
    }
    if (ref.read(eventsProvider) is! AsyncData) return;
    final scope = ref.read(attentionScopeProvider);
    final filter = ref.read(notificationFilterProvider).value;
    if (scope == null || filter == null || filter.read == ReadFilter.read) return;
    final categories = (filter.categories.isEmpty
        ? NotificationCategory.values.toSet() : filter.categories).difference(_seenThisShowing);
    if (categories.isEmpty) return;
    final newVisit = _seenThisShowing.isEmpty;
    _seenThisShowing.addAll(categories);
    if (categories.contains(NotificationCategory.messages) &&
        ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.memberNotifications)) {
      unawaited(ref.read(unreadNoteCountProvider.notifier).markAllSeen());
    }
    if (filter.categories.isEmpty) unawaited(ref.read(eventsSeenCutoffProvider.notifier).markOpened());
    unawaited(ref.read(updatesSeenProvider(scope).notifier).markOpened(categories: categories, newVisit: newVisit));
  }


  String _line(
    AppLocalizations l10n,
    WorkspaceEvent event,
    Map<String, String> names,
    Map<String, String> targets,
    MoneyFormat currency,
  ) =>
      eventLine(l10n, event, names, targets, currency);

  String _groupTitle(
    AppLocalizations l10n,
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
    AppLocalizations l10n,
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
            tooltip: l10n.notifUngroup,
            onPressed: () => ref
                .read(notificationFilterProvider.notifier)
                .setGrouping(FeedGrouping.none),
            icon: Icon(feedGroupingIcon(grouping), size: 20),
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
    EventType.paymentTermsChange ||
    EventType.leaseChange ||
    EventType.commitmentVariance => Icons.request_quote_outlined,
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
    AppLocalizations l10n,
    WorkspaceEvent event,
    List<EventDecision> decisions,
    List<ValidationPolicy> policies,
  ) =>
      eventQuorumProgress(l10n, event, decisions, policies);

  /// #154 — the localized payment-method line for a payment event, or
  /// null when the payload carries no known method (pre-#154 events, ''
  /// = not specified, or a wire name from a newer app version).
  String? _methodLine(AppLocalizations l10n, WorkspaceEvent event) {
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
  String? _autoValidatedNote(AppLocalizations l10n, WorkspaceEvent event) {
    if (event.payload['auto_validated'] != true) return null;
    return l10n.eventAutoValidated;
  }

  String _when(WorkspaceEvent event) =>
      eventWhen(event, ref.watch(appFormatProvider));

  Widget _eventTile(
    BuildContext context,
    AppLocalizations l10n,
    WorkspaceEvent event, {
    required bool unread,
    required Map<String, String> names,
    required Map<String, String> targets,
    required MoneyFormat currency,
    required List<EventDecision> decisions,
    required List<ValidationPolicy> policies,
  }) =>
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
                              decisions: decisions,
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
                              decisions,
                              policies,
                            ) case final progress?)
                              Text(progress),
                          ],
                        ),
                        // #196 — semantic outcome trailing: pending
                        // waits, applied/confirmed succeeded (green),
                        // rejected failed (red). Expired events carry no
                        // outcome mark.
                        trailing: eventOutcomeMark(context, event.status),
      );

  @override
  Widget build(BuildContext context) {
    _followTab();
    final l10n = context.l10n;
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
    final scope = ref.watch(attentionScopeProvider);
    final seenBefore = scope == null ? ref.watch(eventsSeenCutoffProvider).value
        : ref.watch(updatesSeenProvider(scope)).value?.visitCutoff;
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
            final matchingPending = pendingForMe.where((event) => filter.categories.isEmpty ||
                filter.categories.contains(categoryOfEvent(event))).toList();
            final feed = buildNotificationFeed(
              events: all
                  .where((e) => !pendingForMe.contains(e))
                  .toList(),
              notes: notes,
              unreadNoteIds: unreadIds,
              eventsSeenBefore: seenBefore,
              seenForCategory: scope == null ? null : ref.watch(updatesSeenProvider(scope)).value?.visitFor,
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
                        title: l10n.eventsEmpty,
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
                if (!unreadOnly && matchingPending.isNotEmpty) ...[
                  // #1306 — the same section the calendar shows when the
                  // bell is switched off.
                  PendingDecisionsSection(pending: matchingPending),
                  const Divider(),
                ],
                EventsFilterBar(
                  filter: filter,
                  unreadCount: unreadIds.length,
                  groupingOn: groupingOn,
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
                      _eventTile(
                        context,
                        l10n,
                        event,
                        unread: unread,
                        names: names,
                        targets: targets,
                        currency: currency,
                        decisions: decisions[event.id] ?? const [],
                        policies: policies,
                      ),
                  },
                ],
                if (feed.isEmpty)
                  Padding(
                    padding: AppSpacing.lgAll,
                    child: Text(
                      l10n.uxAlertsFilterEmpty,
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
            l10n.workspaceGenericError,
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
    return ControlsFeedBody(controls: const [HelpHint(HelpHintId.events)], feed: body);
  }
}
