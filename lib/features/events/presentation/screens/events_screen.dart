// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import '../../../../core/help/help_hint.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
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
import '../feed_notes.dart';
import '../widgets/note_row.dart';

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

  String _categoryLabel(
    AppLocalizations? l10n,
    NotificationCategory category,
  ) {
    return switch (category) {
      NotificationCategory.messages =>
        l10n?.eventsMessagesHeader ?? 'Messages',
      NotificationCategory.reservations =>
        l10n?.eventTypeReservation ?? 'Reservation',
      NotificationCategory.checkIns =>
        l10n?.notifCategoryCheckIns ?? 'Check-ins',
      NotificationCategory.money => l10n?.notifCategoryMoney ?? 'Money',
      NotificationCategory.members =>
        l10n?.notifCategoryMembers ?? 'Members',
    };
  }

  String _line(
    AppLocalizations? l10n,
    WorkspaceEvent event,
    Map<String, String> names,
    Map<String, String> targets,
    MoneyFormat currency,
  ) {
    final actor = names[event.actorMemberId] ?? '';
    final target = targets[event.payloadTargetId] ?? '';
    final cents = event.payload['amount_cents'] as int?;
    final amount = cents == null ? '' : currency.formatMinor(cents);
    var line = switch ((event.type, event.action)) {
      (EventType.reservation, EventAction.created) =>
        l10n?.eventReservationCreated(actor, target) ??
            '$actor booked $target',
      (EventType.reservation, EventAction.modified) =>
        l10n?.eventReservationModified(actor, target) ??
            '$actor changed the booking of $target',
      (EventType.reservation, EventAction.cancelled) =>
        l10n?.eventReservationCancelled(actor, target) ??
            '$actor cancelled the booking of $target',
      (EventType.payment, _) =>
        l10n?.eventPaymentSubmitted(actor, amount) ??
            '$actor recorded a payment of $amount',
      (EventType.expense, _) => (l10n?.eventExpenseSubmitted(actor, amount) ??
              '$actor submitted an expense of $amount') +
          // #731 — a supply says what lands on the shelf.
          (event.payload['supply'] is Map
              ? ' · ${(event.payload['supply'] as Map)['quantity']}× '
                  '${(event.payload['supply'] as Map)['name']}'
              : '') +
          // #767 — a deviated scheduled occurrence: the validators judge
          // the DIFFERENCE, so the line names the validated amount and
          // the member's explanation.
          (event.payload['deviation_reason'] is String &&
                  (event.payload['deviation_reason'] as String).isNotEmpty
              ? ' · ${l10n?.eventExpenseDeviation(
                    currency.formatMinor(
                        (event.payload['scheduled_amount_cents'] as num?)
                                ?.toInt() ??
                            0),
                    event.payload['deviation_reason'] as String,
                  ) ?? 'validated ${currency.formatMinor((event.payload['scheduled_amount_cents'] as num?)?.toInt() ?? 0)} — ${event.payload['deviation_reason']}'}'
              : ''),
      (EventType.serviceCharge, _) => l10n?.eventServiceChargeTitle(
            event.payload['name'] as String? ?? '',
            (event.payload['quantity'] as num?)?.toInt() ?? 0,
            amount,
          ) ??
          '${event.payload['name']} '
              '×${event.payload['quantity']} — $amount',
      (EventType.quota, _) => l10n?.eventQuotaRequested(
            actor,
            (event.payload['half_days'] as num?)?.toInt() ?? 0,
            event.payload['period'] as String? ?? '',
          ) ??
          '$actor requests ${event.payload['half_days']} extra '
              'half-days for ${event.payload['period']}',
      (EventType.roleChange, _) => (event.payload['make_admin'] == true
              ? l10n?.eventRolePromote(actor)
              : l10n?.eventRoleDemote(actor)) ??
          '$actor changes a role',
      (EventType.reservationDelete, _) => l10n?.eventReservationDeleteLine(
            actor,
            (event.payload['starts_at'] as String? ?? '')
                .split('T')
                .first,
            event.payload['was_checked_in'] == true
                ? l10n.eventReservationDeleteCheckedIn
                : l10n.eventReservationDeleteUnused,
          ) ??
          '$actor asks to delete the booking of '
              '${(event.payload['starts_at'] as String? ?? '').split('T').first} '
              '(${event.payload['was_checked_in'] == true ? 'checked in' : 'never used'})',
      (EventType.invoiceWriteoff, _) => l10n?.eventInvoiceWriteoffLine(
            actor,
            event.payload['number'] as String? ?? '',
            amount,
          ) ??
          '$actor asks to cancel the remainder of '
              '${event.payload['number']} — $amount',
      (EventType.invoicePayment, _) => l10n?.eventInvoicePaid(
            event.payload['number'] as String? ?? '',
            amount,
          ) ??
          'Invoice ${event.payload['number']} paid — $amount',
      (EventType.invoiceReminder, _) => l10n?.eventInvoiceReminderLine(
            event.payload['number'] as String? ?? '',
            (event.payload['level'] as num?)?.toInt() ?? 1,
            amount,
          ) ??
          'Reminder ${event.payload['level']}: invoice '
              '${event.payload['number']} — $amount still due',
      // #828 — a shared expense distributed.
      (EventType.expenseRepartition, _) => l10n?.eventExpenseRepartitionLine(
            actor,
            event.payload['title'] as String? ?? '',
            amount,
            (event.payload['member_count'] as num?)?.toInt() ?? 0,
          ) ??
          '$actor distributes "${event.payload['title']}" — $amount over ${event.payload['member_count']} members',
      (EventType.expenseSchedule, _) => l10n?.eventExpenseScheduleLine(
            actor,
            event.payload['title'] as String? ?? '',
            amount,
          ) ??
          '$actor schedules "${event.payload['title']}" — $amount recurring',
      (EventType.priceNegotiation, _) => l10n?.eventPriceNegotiationLine(
            actor,
            names[event.subjectMemberId] ?? '',
            [
              if (event.payload['subscription_pct'] != null)
                '${event.payload['subscription_pct']} %',
              if (event.payload['fee_cents'] != null)
                currency.formatMinor((event.payload['fee_cents'] as num).toInt()),
              if (event.payload['overage_fee_cents'] != null)
                '${currency.formatMinor((event.payload['overage_fee_cents'] as num).toInt())}/½',
              if (event.payload['discount_percent'] != null)
                '−${event.payload['discount_percent']} %',
              if (((event.payload['item_count'] as num?)?.toInt() ?? 0) > 0)
                l10n.eventPriceNegotiationItems(
                    (event.payload['item_count'] as num).toInt()),
            ].join(' · '),
          ) ??
          '$actor proposes a deal for ${names[event.subjectMemberId] ?? ''}',
      _ => '${_typeLabel(l10n, event.type)} · ${event.action.name}',
    };
    // Service charges name no actor in the title, so always say whose bill
    // it lands on; other types only when an admin acted for someone else.
    if (!event.actorIsSubject || event.type == EventType.serviceCharge) {
      final subject = names[event.subjectMemberId] ?? '';
      line = '$line ${l10n?.eventForSubject(subject) ?? 'for $subject'}';
    }
    return line;
  }

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
        _categoryLabel(l10n, group.key as NotificationCategory),
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

  String _typeLabel(AppLocalizations? l10n, EventType type) =>
      eventTypeLabel(l10n, type);

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
    };
  }

  /// Quorum progress ("1/2 validations") for pending events whose policy
  /// wants more than one accept; null otherwise.
  String? _quorumProgress(
    AppLocalizations? l10n,
    WorkspaceEvent event,
    List<EventDecision> decisions,
    List<ValidationPolicy> policies,
  ) {
    if (!event.isPending) return null;
    final required = policyFor(event.type.dbName, policies).requiredCount;
    if (required < 2) return null;
    final accepts = decisions.where((d) => d.accept).length;
    return l10n?.eventValidations(accepts, required) ??
        '$accepts/$required validations';
  }

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

  String _when(WorkspaceEvent event) {
    final start = event.payloadStart;
    final end = event.payloadEnd;
    final created = DateFormat.MMMd().add_Hm().format(
          event.createdAt.toLocal(),
        );
    if (start == null || end == null) return created;
    final range = '${DateFormat.MMMEd().format(start.toLocal())} '
        '${DateFormat.Hm().format(start.toLocal())}–'
        '${DateFormat.Hm().format(end.toLocal())}';
    return '$range · $created';
  }

  Future<void> _respond(WorkspaceEvent event, bool accept) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(eventRepositoryProvider)
          .respond(event.id, accept: accept);
    } catch (e, st) {
      debugPrint('respond failed: $e\n$st');
      TraceLogger.instance
          .error('events', 'respond failed', error: e, stackTrace: st);
      if (!mounted) return;
      // Surface the server's reason (#107) — a hidden reason cost a debug
      // round-trip once already.
      final detail = switch (e) {
        PostgrestException(:final message) => message,
        AuthException(:final message) => message,
        _ => null,
      };
      final base = l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.';
      AppSnack.error(context, detail == null ? base : '$base\n$detail');
      return;
    }
    invalidateBookingData(ref);
  }

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      l10n?.eventsPendingHeader ??
                          'Waiting for your confirmation',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  // #440: one COMPACT row per pending decision — message,
                  // one metadata line (time · quorum), actions inline on
                  // the trailing edge. The old layout spent ~300px per
                  // card on a full-width button row of dead space.
                  for (final event in pendingForMe)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm, AppSpacing.xs,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _line(l10n, event, names, targets,
                                        currency),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    switch (_quorumProgress(
                                      l10n,
                                      event,
                                      decisions[event.id] ?? const [],
                                      policies,
                                    )) {
                                      final progress? =>
                                        '${_when(event)} · $progress',
                                      null => _when(event),
                                    },
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  for (final decision
                                      in decisions[event.id] ??
                                          const <EventDecision>[])
                                    _DecisionRow(
                                      decision: decision,
                                      names: names,
                                    ),
                                ],
                              ),
                            ),
                            // #196 semantic colors kept: decline red,
                            // accept green. Decline is an icon (48dp,
                            // tooltip); Accept keeps its word — a money
                            // decision deserves a labeled button.
                            IconButton(
                              tooltip: l10n?.eventReject ?? 'Decline',
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _respond(event, false),
                              icon: const Icon(Icons.close),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppStatusColors.successOf(
                                  Theme.of(context).brightness,
                                ),
                                foregroundColor:
                                    AppStatusColors.onSuccessOf(
                                  Theme.of(context).brightness,
                                ),
                              ),
                              onPressed: () => _respond(event, true),
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(l10n?.eventAccept ?? 'Accept'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(),
                ],
                // #581 — ONE filter line: categories × read state, all
                // persisted. Empty category selection = everything.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                          label: Text(_categoryLabel(l10n, category)),
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
                      const Spacer(),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
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
                            for (final decision in decisions[event.id] ??
                                const <EventDecision>[])
                              _DecisionRow(
                                decision: decision,
                                names: names,
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
                          EventStatus.expired => null,
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

/// One audit-trail row: check/cross + "who · when" (#130, colored #196).
/// Accepts show a green check (the [AppStatusColors] success token so the
/// hue reads on both light and dark surfaces), refusals a red cross
/// (`colorScheme.error`). Sweep rows carry no member and are attributed to
/// the system.
class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision, required this.names});

  final EventDecision decision;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = decision.memberId == null || decision.decidedBySystem
        ? (l10n?.eventSystemDecider ?? 'System')
        : (names[decision.memberId] ?? '');
    final when =
        DateFormat.MMMd().add_Hm().format(decision.decidedAt.toLocal());
    final color = decision.accept
        ? AppStatusColors.successOf(theme.brightness)
        : theme.colorScheme.error;
    final text = decision.accept
        ? (l10n?.eventValidatedBy(name, when) ??
            'Validated by $name · $when')
        : (l10n?.eventRejectedBy(name, when) ??
            'Declined by $name · $when');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          decision.accept
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
