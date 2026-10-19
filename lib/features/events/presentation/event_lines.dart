// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../money/domain/usage_record.dart';
import '../domain/event_decision.dart';
import '../domain/validation_policy.dart';
import '../domain/workspace_event.dart';
import 'event_labels.dart';

// #1306 — the sentences a pending decision is shown with, shared by the
// events face and the calendar, which carries the decisions when the
// bell is switched off. One wording, wherever the question is asked.

/// #2085 — a role's name as an event recorded it ([names] is the
/// `role_names` map of the payload), in [locale], then English, then
/// [fallback] (the key) when the record carries no name at all.
@visibleForTesting
String roleNameIn(Object? names, String locale, String fallback) {
  if (names is Map) {
    final own = names[locale] ?? names['en'];
    if (own is String && own.trim().isNotEmpty) return own;
  }
  return fallback;
}

String eventLine(
  AppLocalizations l10n,
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
      l10n.eventReservationCreated(actor, target),
    (EventType.reservation, EventAction.modified) =>
      l10n.eventReservationModified(actor, target),
    (EventType.reservation, EventAction.cancelled) =>
      l10n.eventReservationCancelled(actor, target),
    (EventType.payment, _) =>
      l10n.eventPaymentSubmitted(actor, amount),
    (EventType.expense, _) => (l10n.eventExpenseSubmitted(actor, amount)) +
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
            ? ' · ${l10n.eventExpenseDeviation(
                  currency.formatMinor(
                      (event.payload['scheduled_amount_cents'] as num?)
                              ?.toInt() ??
                          0),
                  event.payload['deviation_reason'] as String,
                )}'
            : ''),
    (EventType.serviceCharge, _) => l10n.eventServiceChargeTitle(
          event.payload['name'] as String? ?? '',
          (event.payload['quantity'] as num?)?.toInt() ?? 0,
          amount,
        ),
    (EventType.quota, _) => l10n.eventQuotaRequested(
          actor,
          (event.payload['half_days'] as num?)?.toInt() ?? 0,
          event.payload['period'] as String? ?? '',
        ),
    // #2085 — a workspace's own role, given or taken back at once: the
    // payload names the role (as it read that day) and the direction.
    (EventType.roleChange, _) when event.payload.containsKey('role_key') =>
      () {
        final role = roleNameIn(
          event.payload['role_names'],
          l10n.localeName,
          '${event.payload['role_key']}',
        );
        final member = names[event.subjectMemberId] ?? '';
        return event.payload['assign'] == true
            ? (l10n.eventRoleGiven(actor, role, member))
            : (l10n.eventRoleTakenBack(actor, role, member));
      }(),
    (EventType.roleChange, _) => (event.payload['make_admin'] == true
            ? l10n.eventRolePromote(actor)
            : l10n.eventRoleDemote(actor)),
    (EventType.reservationDelete, _) => l10n.eventReservationDeleteLine(
          actor,
          (event.payload['starts_at'] as String? ?? '')
              .split('T')
              .first,
          event.payload['was_checked_in'] == true
              ? l10n.eventReservationDeleteCheckedIn
              : l10n.eventReservationDeleteUnused,
        ),
    (EventType.invoiceWriteoff, _) => l10n.eventInvoiceWriteoffLine(
          actor,
          event.payload['number'] as String? ?? '',
          amount,
        ),
    (EventType.invoicePayment, _) => l10n.eventInvoicePaid(
          event.payload['number'] as String? ?? '',
          amount,
        ),
    (EventType.invoiceReminder, _) => l10n.eventInvoiceReminderLine(
          event.payload['number'] as String? ?? '',
          (event.payload['level'] as num?)?.toInt() ?? 1,
          amount,
        ),
    // #828 — a shared expense distributed.
    (EventType.expenseRepartition, _) => l10n.eventExpenseRepartitionLine(
          actor,
          event.payload['title'] as String? ?? '',
          amount,
          (event.payload['member_count'] as num?)?.toInt() ?? 0,
        ),
    (EventType.expenseSchedule, _) => l10n.eventExpenseScheduleLine(
          actor,
          event.payload['title'] as String? ?? '',
          amount,
        ),
    (EventType.priceNegotiation, _) => l10n.eventPriceNegotiationLine(
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
        ),
    // #833 — an early departure asked for, and an admin clearing a
    // record. Both name the numbers, because the numbers are the ask.
    (EventType.usageCorrection, _) => l10n.eventUsageCorrectionLine(
          actor,
          usageDuration(
              (event.payload['from_minutes'] as num?)?.toInt() ?? 0),
          usageDuration(
              (event.payload['to_minutes'] as num?)?.toInt() ?? 0),
        ),
    // #881 — validators decide on the conditions themselves.
    (EventType.paymentTermsChange, _) =>
      l10n.eventPaymentTermsChangeLine(
            actor,
            (event.payload['inherit'] == true)
                ? (l10n.paymentTermsInherit)
                : ((event.payload['after'] as Map?)?['payment_terms']
                        as String? ??
                    ''),
          ),
    (EventType.usageRecordDelete || EventType.leaseChange, _) =>
      _recordOrLeaseLine(l10n, event, actor, currency),
    _ => '${eventTypeLabel(l10n, event.type)} · ${event.action.name}',
  };
  // Service charges name no actor in the title, so always say whose bill
  // it lands on; other types only when an admin acted for someone else.
  // #2085 — a role given or taken back already names its member.
  final namesMember = event.type == EventType.roleChange &&
      event.payload.containsKey('role_key');
  if ((!event.actorIsSubject || event.type == EventType.serviceCharge) &&
      !namesMember) {
    final subject = names[event.subjectMemberId] ?? '';
    line = '$line ${l10n.eventForSubject(subject)}';
  }
  return line;
}

/// The line of the two types that need more than a one-liner: an admin
/// clearing a usage record, and (#2569) a lease's notice or rent change, where
/// validators decide on what the lease would become.
String _recordOrLeaseLine(
  AppLocalizations l10n,
  WorkspaceEvent event,
  String actor,
  MoneyFormat currency,
) {
  final p = event.payload;
  if (event.type == EventType.usageRecordDelete) {
    return l10n.eventUsageRecordDeleteLine(actor, p['space_label'] as String? ?? '');
  }
  final premises = p['premises'] as String? ?? '';
  if (p['fn'] == 'notice') {
    return l10n.eventLeaseNoticeLine(actor, premises, p['effective_end'] as String? ?? '');
  }
  return l10n.eventLeaseRentLine(
    actor,
    premises,
    currency.formatMinor((p['new_amount_cents'] as num?)?.toInt() ?? 0),
    p['effective_from'] as String? ?? '',
  );
}

/// Quorum progress for pending events whose policy wants more than one
/// accept; null otherwise.
///
/// An open quorum counts what it has: "1/2 validations". A CHAINED rule
/// (#840) is asking for one particular step, so #848 says which one:
/// "Validation 2 of 3 requested". The step is the number the server
/// wrote when the previous accept landed; a rule switched to chained
/// mid-flight has events that never got the marker, and those fall
/// back to the accepts already in hand.
String? eventQuorumProgress(
  AppLocalizations l10n,
  WorkspaceEvent event,
  List<EventDecision> decisions,
  List<ValidationPolicy> policies,
) {
  // Only while pending: the accept that confirms an event leaves the
  // stage one past the end, where it means nothing.
  if (!event.isPending) return null;
  final policy = policyFor(event.type.dbName, policies);
  final required = policy.requiredCount;
  if (required < 2) return null;
  final accepts = decisions.where((d) => d.accept).length;
  if (policy.sequential) {
    final stage = switch (event.payload['validation_stage']) {
      final int value => value,
      final String value => int.tryParse(value) ?? accepts + 1,
      _ => accepts + 1,
    }
        .clamp(1, required);
    return l10n.eventValidationStage(stage, required);
  }
  return l10n.eventValidations(accepts, required);
}

/// When: the booked range when the event carries one, and when it was
/// raised.
String eventWhen(WorkspaceEvent event, AppFormat format) {
  final start = event.payloadStart;
  final end = event.payloadEnd;
  final created = DateFormat.MMMd().add_Hm().format(
        event.createdAt.toLocal(),
      );
  if (start == null || end == null) return created;
  final range = '${DateFormat.MMMEd().format(start.toLocal())} '
      '${format.time(start)}–'
      '${format.time(end)}';
  return '$range · $created';
}
