// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what the space sheet offers for a scanned or tapped desk,
// office, level or seat: the seats it lists, whether the space can be
// taken whole, what blocks it, and my own live booking of it. Decided
// once per build from the resolved space, the window's reservations and
// the member's rights; the sheet only renders the answer. The server
// re-checks everything (offices/levels elsewhere, series, races).
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/office.dart';
import '../../plan/domain/seat.dart';
import 'reservation.dart';
import 'space_code.dart';
import 'whole_space_blocking.dart';

/// A space fully resolved against the live floor plan — what the space
/// sheet wants. Null members follow the kind.
typedef ResolvedSpace = ({
  Level? level,
  Office? office,
  Desk? desk,
  Seat? seat,
  FloorPlan? plan,
});

/// What the member may do with a whole space: [granted] is the personal
/// grant (or the implicit owner/admin right), [canAssign] the roster the
/// caller handed (#638), [featureOn] the whole-space booking feature.
typedef SpaceRights = ({bool granted, bool canAssign, bool featureOn});

/// Whole-space bookability of a desk, office or level (0059 added the
/// desk scale).
typedef WholeTarget = ({bool bookable, int priceCents});

/// The ids a whole-space booking names: exactly one is set, by kind.
typedef WholeSpaceIds = ({String? deskId, String? officeId, String? levelId});

/// The space sheet's decision for one space in one window.
class SpaceBookability {
  const SpaceBookability._({
    required this.kind,
    required this.rights,
    required this.seats,
    required this.wholeTarget,
    required this.blocking,
    required this.myWholeReservation,
    required this.spaceId,
    required this.reservations,
    required this.window,
  });

  /// Decides [kind] on [space] for [window], from the window's
  /// [reservations], the member [myMemberId] (null before the member is
  /// known) and their [rights].
  factory SpaceBookability.of({
    required SpaceKind kind,
    required ResolvedSpace space,
    required List<Reservation> reservations,
    required ({DateTime start, DateTime end}) window,
    required String? myMemberId,
    required SpaceRights rights,
  }) {
    final spaceId = _spaceIdOf(kind, space);
    final desk = space.desk;
    final office = space.office;
    return SpaceBookability._(
      kind: kind,
      rights: rights,
      seats: _seatsShown(kind, space),
      wholeTarget: _wholeTargetOf(kind, space),
      // Visible conflicts disable the whole-space buttons up front; the
      // server re-checks. #622 resolves the blocking RESERVATION (not just
      // a bool) so the conflict note can offer messaging its holder.
      blocking: wholeSpaceBlocking(
        kind: kind,
        plan: space.plan,
        reservations: reservations,
        from: window.start,
        to: window.end,
        deskId: desk?.id,
        officeId: kind == SpaceKind.desk ? desk?.officeId : office?.id,
        levelId: kind == SpaceKind.level ? space.level?.id : office?.levelId,
      ),
      myWholeReservation: myMemberId == null
          ? null
          : myLiveWholeReservation(
              kind,
              reservations,
              myMemberId,
              window,
              spaceId: spaceId,
            ),
      spaceId: spaceId,
      reservations: reservations,
      window: window,
    );
  }

  final SpaceKind kind;
  final SpaceRights rights;

  /// The seats listed: the scanned workstation itself, the desk's own, or
  /// every seat of the office's desks.
  final List<Seat> seats;

  /// Null for a seat: a workstation is never booked whole.
  final WholeTarget? wholeTarget;

  /// The reservation keeping the space from being taken whole now.
  final Reservation? blocking;

  /// My own live booking (reserved or checked in) of exactly this space.
  final Reservation? myWholeReservation;

  /// The desk's, office's or level's id, by kind.
  final String? spaceId;

  /// The reservations of the window the sheet decides for.
  final List<Reservation> reservations;
  final ({DateTime start, DateTime end}) window;

  /// Offered whole: the feature is on, the owner made it bookable, and
  /// the member holds the grant or may assign it.
  bool get allowed =>
      wholeTarget != null &&
      rights.featureOn &&
      wholeTarget!.bookable &&
      (rights.granted || rights.canAssign);

  /// The ids a whole-space booking of this space names.
  WholeSpaceIds get ids => (
    deskId: kind == SpaceKind.desk ? spaceId : null,
    officeId: kind == SpaceKind.office ? spaceId : null,
    levelId: kind == SpaceKind.level ? spaceId : null,
  );

  /// Someone holds [seat] in the window.
  bool seatTaken(Seat seat) => reservations.any(
    (r) => r.seatId == seat.id && r.coversRange(window.start, window.end),
  );
}

/// The scanned desk's, office's or level's id, by kind.
String? _spaceIdOf(SpaceKind kind, ResolvedSpace space) => switch (kind) {
  SpaceKind.desk => space.desk?.id,
  SpaceKind.office => space.office?.id,
  SpaceKind.level => space.level?.id,
  SpaceKind.seat => null,
};

/// The seats the sheet lists for [kind].
List<Seat> _seatsShown(SpaceKind kind, ResolvedSpace space) {
  final plan = space.plan;
  final seats = plan?.seats ?? const <Seat>[];
  return switch (kind) {
    SpaceKind.seat => [?space.seat],
    SpaceKind.desk => seats.where((s) => s.deskId == space.desk?.id).toList(),
    SpaceKind.office => () {
      final deskIds = (plan?.desks ?? const <Desk>[])
          .where((d) => d.officeId == space.office?.id)
          .map((d) => d.id)
          .toSet();
      return seats.where((s) => deskIds.contains(s.deskId)).toList();
    }(),
    SpaceKind.level => const <Seat>[],
  };
}

/// Whole-space bookability of the scanned desk/office/level; null for a
/// seat.
WholeTarget? _wholeTargetOf(SpaceKind kind, ResolvedSpace space) =>
    switch (kind) {
      SpaceKind.desk => (
        bookable: space.desk?.bookableAsWhole ?? false,
        priceCents: space.desk?.priceCents ?? 0,
      ),
      SpaceKind.office => (
        bookable: space.office?.bookableAsWhole ?? false,
        priceCents: space.office?.priceCents ?? 0,
      ),
      SpaceKind.level => (
        bookable: space.level?.bookableAsWhole ?? false,
        priceCents: space.level?.priceCents ?? 0,
      ),
      SpaceKind.seat => null,
    };
