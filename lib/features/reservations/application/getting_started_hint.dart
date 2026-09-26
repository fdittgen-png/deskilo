// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1654 — which ONE next step the Get started card suggests, chosen from
// facts the Reserve hub already holds.
//
// The card that shows this is optional help on an existing screen. It
// suggests, it never does: the three actions it can name — choose a time
// to book, view my membership, open the help — each open a consumer that
// already exists, and every one of them leaves a booking, a payment or
// an approval to that consumer's own confirmation. So the whole decision
// is a pure function over facts that were loaded for other reasons, and
// nothing here reads a provider, writes a preference or calls a server.
//
// What the facts say, they say with their STATE. A membership that is
// still loading is not a missing membership; an allowance the policy has
// not answered is not an allowance of zero; a floor plan the server
// refused is not an empty floor plan; a day the availability query has
// not settled is neither open nor closed. Each of those has its own row
// in the table in test/features/reservations/application/
// getting_started_hint_test.dart, and each of them keeps the card from
// claiming what it does not know.
//
// The owner's first hour is #1636's subject, not this file's. An owner
// who has not set the space up yet gets the same permitted task a member
// gets, through [chooseGettingStartedHint]'s `ownerGuidance` parameter —
// the ONE seam where a readiness checklist plugs in once it exists — and
// [noOwnerReadinessGuidance] is what is plugged in today: nothing,
// deliberately, rather than an invented list.

/// How a fact was obtained, which decides what may be said about it.
enum FactState {
  /// Not answered yet: the query is in flight. Say nothing about it.
  loading,

  /// Answered now.
  ready,

  /// Answered before and being re-asked; the value is the last answer.
  refreshing,

  /// Answered before and known to be out of date (#1305): the value is
  /// the last answer, and a decision on it is provisional.
  stale,

  /// Could not be asked: no connection. Not the same as "none".
  offline,

  /// Asked and refused: the server said no. Not the same as "none".
  refused,
}

/// A fact and the state it was obtained in.
class Fact<T> {
  const Fact.loading() : state = FactState.loading, value = null;
  const Fact.ready(T this.value) : state = FactState.ready;
  const Fact.refreshing(T this.value) : state = FactState.refreshing;
  const Fact.stale(T this.value) : state = FactState.stale;
  const Fact.offline() : state = FactState.offline, value = null;
  const Fact.refused() : state = FactState.refused, value = null;

  final FactState state;
  final T? value;

  /// Whether a decision may rest on [value]: it was answered, however
  /// recently. A loading, offline or refused fact is not known.
  bool get known =>
      value != null &&
      (state == FactState.ready ||
          state == FactState.refreshing ||
          state == FactState.stale);
}

/// My standing in the active workspace, as far as the card cares.
enum MembershipStanding { member, administrator, owner, pending, inactive }

/// A booking of mine the hub has already loaded: the authoritative
/// outcome of the flow the card pointed at, never a tap or a checkbox.
class BookingEvidence {
  const BookingEvidence({required this.id, required this.state});

  /// The reservation's real id, as the server returned it.
  final String id;

  /// The reservation's real state name (`reserved`, `checkedIn`, …).
  final String state;
}

/// Everything the choice is allowed to know.
class GettingStartedFacts {
  const GettingStartedFacts({
    required this.membership,
    this.workspaceName = '',
    this.production = false,
    this.dayOpen = const Fact.loading(),
    this.bookableSpaces = const Fact.loading(),
    this.allowance = const Fact.loading(),
    this.ownBooking = const Fact.loading(),
  });

  final Fact<MembershipStanding> membership;

  /// Shown as context, never as a claim about anything else.
  final String workspaceName;

  /// Whether the workspace declares itself production (#917): the card
  /// names the environment so a member knows which side of a pair the
  /// suggestion applies to.
  final bool production;

  /// Whether the day the hub is looking at is an open day.
  final Fact<bool> dayOpen;

  /// How many bookable spaces the loaded floor plan holds.
  final Fact<int> bookableSpaces;

  /// The simultaneous-booking allowance this member has, as the policy
  /// answered it. Unknown while the policy is loading or the feature is
  /// off — and unknown is NEVER rendered as zero.
  final Fact<int> allowance;

  /// A booking of mine the hub already loaded, if any. `ready(null)` is
  /// the settled answer "none yet"; `loading` is no answer.
  final Fact<BookingEvidence?> ownBooking;
}

/// The one action the card may suggest.
enum GettingStartedAction { chooseTime, viewMembership, openHelp }

/// Why that action, and what the text says. One reason per row of the
/// table, so two hints with the same action stay distinguishable.
enum GettingStartedReason {
  /// The facts are still arriving: nothing is suggested yet.
  loading,

  /// Admission is not decided; the waiting room is the surface, not this.
  pendingAdmission,

  /// The membership itself could not be read: the help is the safe door.
  membershipUnknown,

  /// A booking of mine exists — the hub said so — so the next useful
  /// thing is to read what the membership includes.
  booked,

  /// The day is open and there is something to book.
  readyToBook,

  /// The day is closed; choosing another day is the honest next step.
  closedToday,

  /// The plan holds nothing bookable. Membership info is what a member
  /// may read; creating seats is not something the card asks for.
  noSpaces,

  /// The plan or the day could not be read at all (no connection, or
  /// refused): the help explains, nothing is claimed about availability.
  availabilityUnknown,
}

/// What the card shows: one primary action (or none), why, and the
/// facts it may quote.
class GettingStartedHint {
  const GettingStartedHint({
    required this.reason,
    this.action,
    this.standing,
    this.allowance,
    this.booking,
  });

  final GettingStartedReason reason;
  final GettingStartedAction? action;
  final MembershipStanding? standing;

  /// Quoted only when the policy answered; null otherwise.
  final int? allowance;

  /// Quoted only when the hub loaded it; null otherwise.
  final BookingEvidence? booking;

  /// A hint with no action renders nothing: there is nothing to suggest.
  bool get showsCard => action != null;

  @override
  String toString() =>
      'GettingStartedHint($reason, $action, $standing, allowance: $allowance, '
      'booking: ${booking?.id}/${booking?.state})';
}

/// The seam for an owner's readiness guidance (#1636). Given the facts,
/// answers a hint of its own or null to fall through to the normal
/// permitted task. Nothing in this file decides what an owner should
/// configure; that is the checklist's business once it exists.
typedef OwnerReadinessGuidance =
    GettingStartedHint? Function(GettingStartedFacts facts);

/// What is plugged into the seam today: no owner-specific guidance at
/// all. An owner meets the same permitted task a member does rather
/// than an invented checklist.
GettingStartedHint? noOwnerReadinessGuidance(GettingStartedFacts facts) => null;

/// The version of the guidance a dismissal refers to. Bumped only when
/// the card's MEANING changes enough that a person who dismissed the
/// old one should see the new one; an app release does not bump it.
const int kGettingStartedGuidanceVersion = 1;

/// The key a dismissal is stored under in the device's help-hint store:
/// installation (the backend host), account, workspace and guidance
/// version, so that another account on this phone, the same account on
/// another backend, and a workspace with the same id on another
/// installation each keep their own answer. Null when any part is
/// missing — nothing is stored against an unknown scope.
String? gettingStartedSeenKey({
  required String installation,
  required String accountId,
  required String workspaceId,
  int version = kGettingStartedGuidanceVersion,
}) {
  if (installation.isEmpty || accountId.isEmpty || workspaceId.isEmpty) {
    return null;
  }
  return 'getting-started:v$version:$installation:$accountId:$workspaceId';
}

/// The choice. Pure: reads its arguments and nothing else.
///
/// [dismissed] is the stored answer for THIS scope's key; a dismissed
/// card returns null and nothing else is consulted. [ownerGuidance] is
/// the #1636 seam, consulted only for an owner or an administrator and
/// only after their membership is known.
GettingStartedHint? chooseGettingStartedHint(
  GettingStartedFacts facts, {
  required bool dismissed,
  OwnerReadinessGuidance ownerGuidance = noOwnerReadinessGuidance,
}) {
  if (dismissed) return null;

  final membership = facts.membership;
  if (!membership.known) {
    return switch (membership.state) {
      FactState.loading => const GettingStartedHint(
        reason: GettingStartedReason.loading,
      ),
      // Offline or refused, and nothing known from before: the help is
      // the one door that needs no membership to open.
      _ => const GettingStartedHint(
        reason: GettingStartedReason.membershipUnknown,
        action: GettingStartedAction.openHelp,
      ),
    };
  }
  final standing = membership.value!;
  switch (standing) {
    case MembershipStanding.pending:
      return const GettingStartedHint(
        reason: GettingStartedReason.pendingAdmission,
        standing: MembershipStanding.pending,
      );
    case MembershipStanding.inactive:
      return null;
    case MembershipStanding.owner:
    case MembershipStanding.administrator:
      final own = ownerGuidance(facts);
      if (own != null) return own;
    case MembershipStanding.member:
      break;
  }

  final allowance = facts.allowance.known ? facts.allowance.value : null;

  // The authoritative outcome first: a booking the hub loaded means the
  // suggestion the card made has been acted on, whatever the plan says.
  if (facts.ownBooking.known && facts.ownBooking.value != null) {
    return GettingStartedHint(
      reason: GettingStartedReason.booked,
      action: GettingStartedAction.viewMembership,
      standing: standing,
      allowance: allowance,
      booking: facts.ownBooking.value,
    );
  }

  final spaces = facts.bookableSpaces;
  final day = facts.dayOpen;
  if (spaces.state == FactState.loading || day.state == FactState.loading) {
    return GettingStartedHint(
      reason: GettingStartedReason.loading,
      standing: standing,
    );
  }
  if (!spaces.known || !day.known) {
    return GettingStartedHint(
      reason: GettingStartedReason.availabilityUnknown,
      action: GettingStartedAction.openHelp,
      standing: standing,
      allowance: allowance,
    );
  }
  if (spaces.value! <= 0) {
    return GettingStartedHint(
      reason: GettingStartedReason.noSpaces,
      action: GettingStartedAction.viewMembership,
      standing: standing,
      allowance: allowance,
    );
  }
  return GettingStartedHint(
    reason: day.value!
        ? GettingStartedReason.readyToBook
        : GettingStartedReason.closedToday,
    action: GettingStartedAction.chooseTime,
    standing: standing,
    allowance: allowance,
  );
}
