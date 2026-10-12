// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../core/l10n/lexicon.dart';

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

String workflowName(
  BuildContext context,
  AppLocalizations l10n,
  ValidationWorkflow w,
) =>
    switch (w) {
      ValidationWorkflow.money => lexiconText(context, key: 'tabMoney', fallback: l10n.tabMoney),
      ValidationWorkflow.bookings =>
        l10n.validationWorkflowBookings,
      ValidationWorkflow.people =>
        l10n.validationWorkflowPeople,
    };

/// What is at stake while a rule of this workflow is waiting — the half
/// of the answer the old summary never gave.
String workflowStake(AppLocalizations l10n, ValidationWorkflow w) =>
    switch (w) {
      ValidationWorkflow.money => l10n.validationWorkflowMoneyStake,
      ValidationWorkflow.bookings => l10n.validationWorkflowBookingsStake,
      ValidationWorkflow.people => l10n.validationWorkflowPeopleStake,
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
  AppLocalizations l10n,
  ValidationPolicy policy,
) {
  final who = switch (policy.validatorScope) {
    'members' => l10n.validationScopeMembers,
    'listed' => l10n.validationSpecificAdmins,
    _ => l10n.validationAllAdmins,
  };
  final count = policy.requiredCount;
  return (
    // Whoever raises it is never the one who decides it — the 0086
    // invariant — unless the owner has taken the one exception there
    // is. Said on every card, because it is the first thing that
    // happens and the thing an owner most often forgets they changed.
    asked: policy.ownerMaySelfValidate
        ? '${l10n.validationStepRaised} · '
            '${l10n.validationOwnerSelfShort}'
        : '${l10n.validationStepRaised} · '
            '${l10n.validationNoSelfShort}',
    decide: policy.sequential
        ? (l10n.validationStepSequential(count, who))
        : (l10n.validationStepQuorum(count, who)),
    then: policy.ownerRequired
        ? (l10n.validationStepOwnerToo)
        : (l10n.validationStepApplies),
  );
}
