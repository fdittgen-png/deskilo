// SPDX-License-Identifier: 0BSD
import '../../events/domain/workspace_event.dart';
import '../domain/dunning.dart';
import '../domain/invoice.dart';
import 'invoice_status.dart';

/// #812 — the four steps every invoice walks through, in order. The same
/// four on every surface, so an issuer's hub and a member's face tell one
/// story: the document is ISSUED, the money is PAID, the payment is
/// CONFIRMED (declared → registered → matched → validated), the invoice
/// is CLOSED.
enum InvoiceStep { issued, payment, confirmation, closed }

/// Where one step stands on the journey bar.
enum InvoiceStepState {
  done,
  current,
  todo,

  /// The closed step of an ERRONEOUS invoice: it ended, but not by being
  /// paid.
  cancelled,
}

/// Whose move it is, and what the move is. ONE value per invoice, chosen
/// by priority: a pending decision beats a registered payment, which
/// beats a declared one, which beats waiting for the member to pay.
enum InvoiceMove {
  /// Open, nothing declared or registered: the member pays.
  memberPays,

  /// Partially paid, nothing new on the way: the member pays the rest.
  memberPaysRemainder,

  /// The member recorded "I paid" — another admin confirms it in Events
  /// (no self-approval, spec §9).
  adminConfirmsPayment,

  /// An admin recorded a payment FOR the member — the member confirms it
  /// in Events.
  memberConfirmsPayment,

  /// A confirmed payment sits on the member's ledger, not yet matched to
  /// this invoice: the issuer marks it paid.
  issuerMatchesPayment,

  /// The match is pending its validation quorum (0067).
  validatorsDecideMatch,

  /// The write-off of the remainder is pending its quorum (#504).
  validatorsDecideWriteoff,

  /// A credit note the workspace still has to pay out (#508).
  issuerRefunds,

  /// Tagged erroneous and not replaced yet: the issuer re-issues (0061).
  issuerReplaces,

  /// Closed — nothing is expected from anyone.
  none,
}

/// Who acts on an [InvoiceMove].
enum InvoiceMover { member, issuer, validators, nobody }

extension InvoiceMoveWho on InvoiceMove {
  InvoiceMover get who => switch (this) {
        InvoiceMove.memberPays ||
        InvoiceMove.memberPaysRemainder ||
        InvoiceMove.memberConfirmsPayment =>
          InvoiceMover.member,
        InvoiceMove.adminConfirmsPayment ||
        InvoiceMove.issuerMatchesPayment ||
        InvoiceMove.issuerRefunds ||
        InvoiceMove.issuerReplaces =>
          InvoiceMover.issuer,
        InvoiceMove.validatorsDecideMatch ||
        InvoiceMove.validatorsDecideWriteoff =>
          InvoiceMover.validators,
        InvoiceMove.none => InvoiceMover.nobody,
      };
}

/// What the member's payment EVENTS say about an invoice — read once from
/// the feed, then handed to [InvoiceJourney.of] as plain facts so the
/// derivation stays pure and testable.
typedef InvoiceJourneyFacts = ({
  /// Sum of the member's PENDING payment events they recorded themselves
  /// ("I paid", awaiting another admin).
  int declaredCents,

  /// Sum of the member's PENDING payment events an admin recorded for
  /// them (awaiting the member).
  int recordedForMemberCents,

  /// Sum of the member's CONFIRMED payments booked since the invoice was
  /// issued (or since its standing partial match) — money on the ledger
  /// that no match has consumed yet, as far as the feed can tell.
  int registeredCents,

  /// Whether a write-off of the remainder is pending its quorum.
  bool writeoffPending,
});

const InvoiceJourneyFacts noJourneyFacts = (
  declaredCents: 0,
  recordedForMemberCents: 0,
  registeredCents: 0,
  writeoffPending: false,
);

/// Reads the [InvoiceJourneyFacts] of [invoice] out of the workspace's
/// event feed. A payment counts as registered when it was booked AFTER
/// the invoice (a payment recorded before issue was netted into the
/// document itself, 0063) — or after the standing partial match, which
/// consumed what came before it.
InvoiceJourneyFacts journeyFactsOf(
  Invoice invoice,
  InvoiceMatch? match,
  Iterable<WorkspaceEvent> events,
) {
  var declared = 0;
  var recordedForMember = 0;
  var registered = 0;
  var writeoffPending = false;
  final partialSince = match != null &&
          !match.pending &&
          match.resolution == 'under_accepted' &&
          match.writeoffAt == null
      ? match.matchedAt
      : invoice.issuedAt;
  for (final event in events) {
    if (event.type == EventType.invoiceWriteoff) {
      if (event.isPending &&
          event.payload['invoice_id'] == invoice.id) {
        writeoffPending = true;
      }
      continue;
    }
    if (event.type != EventType.payment ||
        event.subjectMemberId != invoice.memberId) {
      continue;
    }
    final amount = (event.payload['amount_cents'] as num?)?.toInt() ?? 0;
    if (event.isPending) {
      if (event.actorIsSubject) {
        declared += amount;
      } else {
        recordedForMember += amount;
      }
      continue;
    }
    final confirmed = event.status == EventStatus.confirmed ||
        event.status == EventStatus.applied;
    if (confirmed && event.createdAt.isAfter(partialSince)) {
      registered += amount;
    }
  }
  return (
    declaredCents: declared,
    recordedForMemberCents: recordedForMember,
    registeredCents: registered,
    writeoffPending: writeoffPending,
  );
}

/// The journey of one invoice: its lifecycle, the state of each step, the
/// next move and the figures that move needs (what is still owed, the
/// due date, the reminder that is due). Derived, never stored.
class InvoiceJourney {
  const InvoiceJourney({
    required this.lifecycle,
    required this.move,
    required this.remainingCents,
    required this.dueOn,
    required this.daysToTerm,
    required this.reminderDue,
    required this.reminderCount,
    required this.facts,
    required this.replacedByNumber,
    this.settled = false,
  });

  final InvoiceLifecycle lifecycle;
  final InvoiceMove move;

  /// Positive: the member still owes it. Negative: the workspace owes it
  /// back (an open credit note). Zero: settled.
  final int remainingCents;

  /// The payment term: issue date plus the dunning rules' first delay —
  /// the same clock #726 reads.
  final DateTime dueOn;

  /// Days until the term (positive) or past it (zero or negative).
  final int daysToTerm;

  /// The reminder level the rules say is due now, or null.
  final int? reminderDue;
  final int reminderCount;
  final InvoiceJourneyFacts facts;
  final String replacedByNumber;

  /// #804 — regrouped into a settlement: THAT document is owed and
  /// chased; this one is closed here.
  final bool settled;

  bool get closed => move == InvoiceMove.none;

  /// Past the term while the member still has to pay.
  bool get overdue =>
      (move == InvoiceMove.memberPays ||
          move == InvoiceMove.memberPaysRemainder) &&
      daysToTerm <= 0;

  /// The state of every step, in journey order.
  Map<InvoiceStep, InvoiceStepState> get steps {
    if (lifecycle == InvoiceLifecycle.erroneous) {
      return const {
        InvoiceStep.issued: InvoiceStepState.done,
        InvoiceStep.payment: InvoiceStepState.todo,
        InvoiceStep.confirmation: InvoiceStepState.todo,
        InvoiceStep.closed: InvoiceStepState.cancelled,
      };
    }
    if (closed) {
      return const {
        InvoiceStep.issued: InvoiceStepState.done,
        InvoiceStep.payment: InvoiceStepState.done,
        InvoiceStep.confirmation: InvoiceStepState.done,
        InvoiceStep.closed: InvoiceStepState.done,
      };
    }
    final paying = switch (move) {
      InvoiceMove.memberPays ||
      InvoiceMove.memberPaysRemainder ||
      InvoiceMove.issuerRefunds =>
        true,
      _ => false,
    };
    return {
      InvoiceStep.issued: InvoiceStepState.done,
      InvoiceStep.payment:
          paying ? InvoiceStepState.current : InvoiceStepState.done,
      InvoiceStep.confirmation:
          paying ? InvoiceStepState.todo : InvoiceStepState.current,
      InvoiceStep.closed: InvoiceStepState.todo,
    };
  }

  static InvoiceJourney of({
    required Invoice invoice,
    required InvoiceMatch? match,
    required ({int count, DateTime last})? reminder,
    required DunningRules rules,
    required DateTime now,
    InvoiceJourneyFacts facts = noJourneyFacts,
    String replacedByNumber = '',
  }) {
    final lifecycle = invoiceLifecycleOf(invoice, match);
    final remaining = switch (lifecycle) {
      InvoiceLifecycle.open ||
      InvoiceLifecycle.awaitingValidation =>
        invoice.totalCents,
      InvoiceLifecycle.partiallyPaid =>
        invoice.totalCents - (match?.paidCents ?? 0),
      _ => 0,
    };
    final settled = invoice.settledByInvoiceId != null &&
        (lifecycle == InvoiceLifecycle.open ||
            lifecycle == InvoiceLifecycle.partiallyPaid);
    final move = switch (lifecycle) {
      _ when settled => InvoiceMove.none,
      InvoiceLifecycle.paid ||
      InvoiceLifecycle.remainderCancelled ||
      InvoiceLifecycle.refunded =>
        InvoiceMove.none,
      InvoiceLifecycle.erroneous => replacedByNumber.isEmpty
          ? InvoiceMove.issuerReplaces
          : InvoiceMove.none,
      InvoiceLifecycle.awaitingValidation => InvoiceMove.validatorsDecideMatch,
      // #508 — a credit note is the WORKSPACE's debt: no member payment
      // is ever expected on it.
      InvoiceLifecycle.open when invoice.totalCents < 0 =>
        InvoiceMove.issuerRefunds,
      InvoiceLifecycle.open || InvoiceLifecycle.partiallyPaid =>
        _openMove(lifecycle, facts),
    };
    final count = reminder?.count ?? 0;
    return InvoiceJourney(
      lifecycle: lifecycle,
      move: move,
      settled: settled,
      remainingCents: settled ? 0 : remaining,
      dueOn: invoice.issuedAt.add(Duration(days: rules.firstAfterDays)),
      daysToTerm:
          rules.firstAfterDays - now.difference(invoice.issuedAt).inDays,
      reminderDue: remaining > 0 &&
              !settled &&
              (lifecycle == InvoiceLifecycle.open ||
                  lifecycle == InvoiceLifecycle.partiallyPaid)
          ? dueReminderLevel(
              issuedAt: invoice.issuedAt,
              reminderCount: count,
              lastReminderAt: reminder?.last,
              rules: rules,
              now: now,
            )
          : null,
      reminderCount: count,
      facts: facts,
      replacedByNumber: replacedByNumber,
    );
  }

  static InvoiceMove _openMove(
    InvoiceLifecycle lifecycle,
    InvoiceJourneyFacts facts,
  ) {
    if (lifecycle == InvoiceLifecycle.partiallyPaid && facts.writeoffPending) {
      return InvoiceMove.validatorsDecideWriteoff;
    }
    if (facts.registeredCents > 0) return InvoiceMove.issuerMatchesPayment;
    if (facts.declaredCents > 0) return InvoiceMove.adminConfirmsPayment;
    if (facts.recordedForMemberCents > 0) {
      return InvoiceMove.memberConfirmsPayment;
    }
    return lifecycle == InvoiceLifecycle.partiallyPaid
        ? InvoiceMove.memberPaysRemainder
        : InvoiceMove.memberPays;
  }
}

/// The issuer's four stages, for the hub's strip: what the open list
/// holds, split by whose move it is.
typedef InvoiceStageCounts = ({
  int toIssue,
  int toCollect,
  int toCollectCents,
  int overdue,
  int toConfirm,
  int closed,
});

/// Folds the journeys of every open invoice into the stage counts. A
/// credit note to refund counts as a confirmation-side move (the issuer
/// acts), never as money to collect.
InvoiceStageCounts stageCountsOf({
  required int toIssue,
  required Iterable<InvoiceJourney> open,
  required int closed,
}) {
  var toCollect = 0;
  var toCollectCents = 0;
  var overdue = 0;
  var toConfirm = 0;
  for (final journey in open) {
    switch (journey.move) {
      case InvoiceMove.memberPays:
      case InvoiceMove.memberPaysRemainder:
        toCollect++;
        toCollectCents += journey.remainingCents;
        if (journey.overdue) overdue++;
      case InvoiceMove.none:
      case InvoiceMove.issuerReplaces:
        break;
      default:
        toConfirm++;
    }
  }
  return (
    toIssue: toIssue,
    toCollect: toCollect,
    toCollectCents: toCollectCents,
    overdue: overdue,
    toConfirm: toConfirm,
    closed: closed,
  );
}
