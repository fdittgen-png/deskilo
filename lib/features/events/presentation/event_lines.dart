// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';

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

String eventLine(
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
    // #833 — an early departure asked for, and an admin clearing a
    // record. Both name the numbers, because the numbers are the ask.
    (EventType.usageCorrection, _) => l10n?.eventUsageCorrectionLine(
          actor,
          usageDuration(
              (event.payload['from_minutes'] as num?)?.toInt() ?? 0),
          usageDuration(
              (event.payload['to_minutes'] as num?)?.toInt() ?? 0),
        ) ??
        '$actor asks to be billed less',
    // #881 — validators decide on the conditions themselves.
    (EventType.paymentTermsChange, _) =>
      l10n?.eventPaymentTermsChangeLine(
            actor,
            (event.payload['inherit'] == true)
                ? (l10n.paymentTermsInherit)
                : ((event.payload['after'] as Map?)?['payment_terms']
                        as String? ??
                    ''),
          ) ??
          '$actor asks to change payment conditions',
    (EventType.usageRecordDelete, _) => l10n?.eventUsageRecordDeleteLine(
          actor,
          event.payload['space_label'] as String? ?? '',
        ) ??
        '$actor asks to remove a usage record',
    _ => '${eventTypeLabel(l10n, event.type)} · ${event.action.name}',
  };
  // Service charges name no actor in the title, so always say whose bill
  // it lands on; other types only when an admin acted for someone else.
  if (!event.actorIsSubject || event.type == EventType.serviceCharge) {
    final subject = names[event.subjectMemberId] ?? '';
    line = '$line ${l10n?.eventForSubject(subject) ?? 'for $subject'}';
  }
  return line;
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
  AppLocalizations? l10n,
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
    return l10n?.eventValidationStage(stage, required) ??
        'Validation $stage of $required requested';
  }
  return l10n?.eventValidations(accepts, required) ??
      '$accepts/$required validations';
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
