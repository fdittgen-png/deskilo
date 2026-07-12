// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import '../../../../core/theme/status_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../money/domain/payment_method.dart';
import '../../../money/presentation/payment_method_labels.dart';
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
                              _DecisionRow(
                                decision: decision,
                                names: names,
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
                                // #196 — semantic outcome colors: decline
                                // red (theme error), accept green (the
                                // AppStatusColors success token).
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                  ),
                                  onPressed: () => _respond(event, false),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: Text(
                                    l10n?.eventReject ?? 'Decline',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        AppStatusColors.successOf(
                                      Theme.of(context).brightness,
                                    ),
                                    foregroundColor:
                                        AppStatusColors.onSuccessOf(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                  onPressed: () => _respond(event, true),
                                  icon: const Icon(Icons.check, size: 18),
                                  label:
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_when(event)),
                        // #154 — how the money moved; absent / pre-#154
                        // payloads render no method line.
                        if (_methodLine(l10n, event) case final method?)
                          Text(method),
                        for (final decision
                            in decisions[event.id] ??
                                const <EventDecision>[])
                          _DecisionRow(decision: decision, names: names),
                        // Quorum progress stays neutral: it only renders
                        // while the event is pending, i.e. before the
                        // quorum is satisfied (#196).
                        if (_quorumProgress(
                          l10n,
                          event,
                          decisions[event.id] ?? const [],
                          policies,
                        ) case final progress?)
                          Text(progress),
                      ],
                    ),
                    // #196 — semantic outcome trailing: pending waits,
                    // applied/confirmed succeeded (green), rejected failed
                    // (red). Expired events carry no outcome mark.
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
                          color: Theme.of(context).colorScheme.error,
                        ),
                      EventStatus.expired => null,
                    },
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
