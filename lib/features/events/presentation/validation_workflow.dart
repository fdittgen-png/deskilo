// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/validation_policy.dart';
import '../domain/workspace_event.dart';

/// #1221 — which workflow a validation rule sits in.
///
/// The screen listed twenty-four rules in one hand-ordered column, so
/// reading it meant knowing what each event type was before you could
/// tell whether its rule mattered to you. Grouped by the process they
/// interrupt, a rule is findable by the thing it slows down.
enum ValidationWorkflow { money, bookings, people }

ValidationWorkflow workflowOf(EventType type) => switch (type) {
      EventType.payment ||
      EventType.expense ||
      EventType.serviceCharge ||
      EventType.invoicePayment ||
      EventType.invoiceWriteoff ||
      EventType.invoiceIssue ||
      EventType.invoiceVoid ||
      EventType.refund ||
      EventType.priceNegotiation ||
      EventType.expenseSchedule ||
      EventType.expenseRepartition ||
      EventType.paymentTermsChange ||
      EventType.usageCorrection ||
      EventType.usageRecordDelete =>
        ValidationWorkflow.money,
      EventType.reservation ||
      EventType.spaceReservation ||
      EventType.reservationDelete ||
      EventType.quota =>
        ValidationWorkflow.bookings,
      _ => ValidationWorkflow.people,
    };

String workflowName(AppLocalizations? l10n, ValidationWorkflow w) =>
    switch (w) {
      ValidationWorkflow.money => l10n?.tabMoney ?? 'Money',
      ValidationWorkflow.bookings =>
        l10n?.validationWorkflowBookings ?? 'Bookings',
      ValidationWorkflow.people =>
        l10n?.validationWorkflowPeople ?? 'People and roles',
    };

/// What is at stake while a rule of this workflow is waiting — the half
/// of the answer the old summary never gave.
String workflowStake(AppLocalizations? l10n, ValidationWorkflow w) =>
    switch (w) {
      ValidationWorkflow.money => l10n?.validationWorkflowMoneyStake ??
          'Until it is accepted, the amount does not count on anybody\'s '
              'statement.',
      ValidationWorkflow.bookings => l10n?.validationWorkflowBookingsStake ??
          'Until it is accepted, the seat stays as it was.',
      ValidationWorkflow.people => l10n?.validationWorkflowPeopleStake ??
          'Until it is accepted, the person keeps the access they have '
              'now.',
    };

IconData workflowIcon(ValidationWorkflow w) => switch (w) {
      ValidationWorkflow.money => Icons.account_balance_wallet_outlined,
      ValidationWorkflow.bookings => Icons.event_seat_outlined,
      ValidationWorkflow.people => Icons.people_outline,
    };

/// The three steps a pending act walks through, as this rule shapes
/// them (#1221).
///
/// A rule used to read "2 required · All admins · Owner must always
/// validate" — three true facts in a row, none of which says what
/// HAPPENS. These are the same facts arranged as the process: who is
/// asked, how many have to say yes, and what it takes to move.
typedef ValidationSteps = ({String asked, String decide, String then});

ValidationSteps validationSteps(
  AppLocalizations? l10n,
  ValidationPolicy policy,
) {
  final who = switch (policy.validatorScope) {
    'members' => l10n?.validationScopeMembers ?? 'Every member',
    'listed' => l10n?.validationSpecificAdmins ?? 'Specific admins',
    _ => l10n?.validationAllAdmins ?? 'All admins',
  };
  final count = policy.requiredCount;
  return (
    // Whoever raises it is never the one who decides it — the 0086
    // invariant — unless the owner has taken the one exception there
    // is. Said on every card, because it is the first thing that
    // happens and the thing an owner most often forgets they changed.
    asked: policy.ownerMaySelfValidate
        ? '${l10n?.validationStepRaised ?? 'Someone asks'} · '
            '${l10n?.validationOwnerSelfShort ?? 'Owner may validate their own'}'
        : '${l10n?.validationStepRaised ?? 'Someone asks'} · '
            '${l10n?.validationNoSelfShort ?? 'Never your own'}',
    decide: policy.sequential
        ? (l10n?.validationStepSequential(count, who) ??
            '$who — $count in turn')
        : (l10n?.validationStepQuorum(count, who) ?? '$who — any $count'),
    then: policy.ownerRequired
        ? (l10n?.validationStepOwnerToo ?? 'and the owner, always')
        : (l10n?.validationStepApplies ?? 'it takes effect'),
  );
}
