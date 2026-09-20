// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1281 — how many seat states a space tells apart, for the legend AND
// for the canvas.
//
// It lives in core/theme beside `SeatState` because that is what it is
// about: how a seat is DRAWN. It was briefly in the workspace feature's
// domain, and `layering_test` was right to object — the reservations
// screens are its main reader, and a vocabulary two features share is a
// seam, not a dependency between them.

/// #1281 — how many states the plan tells apart, for the legend AND for
/// the canvas (`booking_rules.legend_profile`).
///
/// The field report asked for four words where the app draws six
/// states. Two requests hide in that sentence, and answering only the
/// first produces a bug: collapsing the LEGEND while the canvas keeps
/// painting five colours leaves a member looking at a colour with no
/// entry explaining it — worse off than reading five entries.
///
/// So this is a profile, and both the legend and the painter read it
/// through [legendGroupOf]. One mapping, not two lists that happen to
/// agree.
///
/// [full] is the default and is exactly today's behaviour: most spaces
/// want to know who is physically present. [simple] is a choice a space
/// makes for itself, and the thing it gives up is stated where the
/// choice is offered — under it, a booked seat and one somebody has
/// checked into look the same.
enum LegendProfile {
  /// Free · Reserved · Checked in · Mine · Blocked (· Closed day).
  full('full'),

  /// Free · Reserved · Mine · Unavailable — «Place libre · Place
  /// réservée · Ma place · Place non disponible».
  simple('simple');

  const LegendProfile(this.wire);

  /// The `booking_rules` string value.
  final String wire;

  /// Absent or unknown reads as [full]: a space that never chose keeps
  /// the picture it has.
  static LegendProfile fromWire(Object? value) {
    for (final profile in values) {
      if (profile.wire == value) return profile;
    }
    return full;
  }
}

/// What a seat state is called and coloured AS, under [profile].
///
/// The single source #1281 asks for. `SeatLegend` lists the distinct
/// results; the painter colours each seat by the result. They cannot
/// disagree, because there is nothing to keep in step.
///
/// Under [LegendProfile.simple], `occupied` folds into `reserved` —
/// both are «taken by somebody» — and `blocked` carries the closed-day
/// meaning too, which is why the entry is worded *unavailable* rather
/// than *blocked*.
SeatGroup legendGroupOf(SeatStateKind state, LegendProfile profile) =>
    switch (profile) {
      LegendProfile.full => switch (state) {
          SeatStateKind.free => SeatGroup.free,
          SeatStateKind.reserved => SeatGroup.reserved,
          SeatStateKind.occupied => SeatGroup.occupied,
          SeatStateKind.mine => SeatGroup.mine,
          SeatStateKind.blocked => SeatGroup.blocked,
          SeatStateKind.closed => SeatGroup.closed,
        },
      LegendProfile.simple => switch (state) {
          SeatStateKind.free => SeatGroup.free,
          // Booked is booked: whether the person has arrived is a fact
          // this profile deliberately stops telling.
          SeatStateKind.reserved || SeatStateKind.occupied =>
            SeatGroup.reserved,
          SeatStateKind.mine => SeatGroup.mine,
          // Blocked and closed are both «you cannot have this».
          SeatStateKind.blocked || SeatStateKind.closed =>
            SeatGroup.unavailable,
        },
    };

/// The states the app can distinguish, independent of how they are
/// drawn. `SeatState` in `seat_state_colors.dart` is the painter's
/// enum and carries no closed-day member because a closed day is drawn
/// by the grid rather than by a seat; this one is the full vocabulary
/// the legend has to speak about.
enum SeatStateKind { free, reserved, occupied, mine, blocked, closed }

/// What a member is shown: one entry in the legend, one colour on the
/// canvas.
enum SeatGroup { free, reserved, occupied, mine, blocked, closed, unavailable }
