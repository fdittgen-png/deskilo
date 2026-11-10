// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3548 -- what a person has to turn up for, whatever the business sells:
// a place they booked today, an appointment or a session tomorrow. Me reads
// commitments only through this type, so it never learns what a seat, a desk
// or a floor plan is. Pure Dart: the adapters that make one live beside the
// feature that owns the source (`application/personal_commitments.dart`).
import 'package:meta/meta.dart';

/// What the commitment is.
enum CommitmentKind { place, appointment, session, other }

/// What a place commitment holds; [other] for a place a reader does not
/// know (a business of a later version): the row still shows.
enum CommitmentPlace { seat, desk, office, level, other }

/// Where a commitment stands.
enum CommitmentState { upcoming, ongoing, done, cancelled }

/// One commitment of the person's, in one business.
@immutable
class PersonalCommitment {
  const PersonalCommitment({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.kind,
    required this.label,
    required this.startsAt,
    required this.endsAt,
    required this.zone,
    required this.state,
    required this.canCheckIn,
    required this.source,
    this.place,
  });

  final String id;
  final String businessId;
  final String businessName;
  final CommitmentKind kind;

  /// What a [CommitmentKind.place] commitment holds; null for the others.
  final CommitmentPlace? place;

  /// The name of what was booked; may be empty (an unnamed seat).
  final String label;
  final DateTime startsAt;
  final DateTime endsAt;

  /// The IANA zone of the business; null when its host named none.
  final String? zone;
  final CommitmentState state;

  /// The person may check in now (inside the window the source opens).
  final bool canCheckIn;

  /// The installation the commitment was read from.
  final String source;

  /// Still to come or under way: what "Next up" is made of.
  bool get stands =>
      state == CommitmentState.upcoming || state == CommitmentState.ongoing;
}
