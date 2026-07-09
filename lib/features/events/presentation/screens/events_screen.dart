// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/event_decision.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../../providers/event_providers.dart';

/// The Events space (spec §8.1): pending confirmations pinned on top,
/// audited feed below. Server RLS scopes workers to their own events and
/// admins to everything.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  EventType? _typeFilter;

  String _line(
    AppLocalizations? l10n,
    WorkspaceEvent event,
    Map<String, String> names,
    Map<String, String> targets,
    NumberFormat currency,
  ) {
    final actor = names[event.actorMemberId] ?? '';
    final target = targets[event.payloadTargetId] ?? '';
    final cents = event.payload['amount_cents'] as int?;
    final amount = cents == null ? '' : currency.format(cents / 100);
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
      (EventType.expense, _) =>
        l10n?.eventExpenseSubmitted(actor, amount) ??
            '$actor submitted an expense of $amount',
      (EventType.serviceCharge, _) => l10n?.eventServiceChargeTitle(
            event.payload['name'] as String? ?? '',
            (event.payload['quantity'] as num?)?.toInt() ?? 0,
            amount,
          ) ??
          '${event.payload['name']} '
              '×${event.payload['quantity']} — $amount',
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

  String _typeLabel(AppLocalizations? l10n, EventType type) {
    return switch (type) {
      EventType.reservation => l10n?.eventTypeReservation ?? 'Reservation',
      EventType.payment => l10n?.eventTypePayment ?? 'Payment',
      EventType.expense => l10n?.eventTypeExpense ?? 'Expense',
      EventType.adjustment => l10n?.eventTypeAdjustment ?? 'Adjustment',
      EventType.serviceCharge =>
        l10n?.eventTypeServiceCharge ?? 'Service',
    };
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
    };
  }

  /// One audit-trail row: "✓/✗ who · when" (#130). Sweep rows carry no
  /// member and are attributed to the system.
  String _decisionLine(
    AppLocalizations? l10n,
    EventDecision decision,
    Map<String, String> names,
  ) {
    final name = decision.memberId == null || decision.decidedBySystem
        ? (l10n?.eventSystemDecider ?? 'System')
        : (names[decision.memberId] ?? '');
    final when =
        DateFormat.MMMd().add_Hm().format(decision.decidedAt.toLocal());
    return decision.accept
        ? '✓ ${l10n?.eventValidatedBy(name, when) ?? 'Validated by $name · $when'}'
        : '✗ ${l10n?.eventRejectedBy(name, when) ?? 'Declined by $name · $when'}';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detail == null ? base : '$base\n$detail'),
        ),
      );
      return;
    }
    invalidateBookingData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eventsAsync = ref.watch(eventsProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final myMember = ref.watch(myMemberProvider).value;
    final members = ref.watch(workspaceMembersProvider).value ?? const [];
    final decisions = ref.watch(eventDecisionsProvider).value ??
        const <String, List<EventDecision>>{};
    final policies =
        ref.watch(validationPoliciesProvider).value ?? const [];
    final currency = NumberFormat.simpleCurrency(
      name: ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
    );

    return switch (eventsAsync) {
      AsyncData(value: final all) => Builder(
          builder: (context) {
            final pendingForMe = all.where((e) {
              if (myMember == null) return false;
              final policy = policyFor(e.type.dbName, policies);
              return e.isDecidedBy(
                myMember,
                policy: policy,
                hasOtherEligibleValidator:
                    e.hasOtherEligibleValidator(members, policy),
                alreadyDecided: (decisions[e.id] ?? const [])
                    .any((d) => d.memberId == myMember.id),
              );
            }).toList();
            final feed = all
                .where((e) => !pendingForMe.contains(e))
                .where(
                  (e) => _typeFilter == null || e.type == _typeFilter,
                )
                .toList();
            if (all.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => invalidateBookingData(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(l10n?.eventsEmpty ?? 'No events yet.'),
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
                if (pendingForMe.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l10n?.eventsPendingHeader ??
                          'Waiting for your confirmation',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final event in pendingForMe)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_line(l10n, event, names, targets, currency)),
                            const SizedBox(height: 4),
                            Text(
                              _when(event),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            for (final decision
                                in decisions[event.id] ??
                                    const <EventDecision>[]) ...[
                              const SizedBox(height: 2),
                              Text(
                                _decisionLine(l10n, decision, names),
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (_quorumProgress(
                              l10n,
                              event,
                              decisions[event.id] ?? const [],
                              policies,
                            ) case final progress?) ...[
                              const SizedBox(height: 4),
                              Text(
                                progress,
                                style:
                                    Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _respond(event, false),
                                  child: Text(
                                    l10n?.eventReject ?? 'Decline',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () => _respond(event, true),
                                  child:
                                      Text(l10n?.eventAccept ?? 'Accept'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n?.eventsFilterAll ?? 'All'),
                        selected: _typeFilter == null,
                        onSelected: (_) =>
                            setState(() => _typeFilter = null),
                      ),
                      for (final type in EventType.values)
                        FilterChip(
                          label: Text(_typeLabel(l10n, type)),
                          selected: _typeFilter == type,
                          onSelected: (_) =>
                              setState(() => _typeFilter = type),
                        ),
                    ],
                  ),
                ),
                for (final event in feed)
                  ListTile(
                    leading: Icon(_icon(event)),
                    title: Text(_line(l10n, event, names, targets, currency)),
                    subtitle: Text(
                      [
                        _when(event),
                        for (final decision
                            in decisions[event.id] ??
                                const <EventDecision>[])
                          _decisionLine(l10n, decision, names),
                        ?_quorumProgress(
                          l10n,
                          event,
                          decisions[event.id] ?? const [],
                          policies,
                        ),
                      ].join('\n'),
                    ),
                    trailing: event.status == EventStatus.pending
                        ? const Icon(Icons.hourglass_top, size: 18)
                        : null,
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
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
