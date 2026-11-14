// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — what the server answers a dated change of a member's share or a
// pause (0766): applied at once, waiting for its date, or held for an
// approval; the date it is in force from; for a pause, the months that stay
// charged in full, the first month it frees and the member's bookings in
// the months it frees. A date the server refuses comes back with the
// earliest it can take.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'member_term_change.dart';

class MemberTermAnswer {
  const MemberTermAnswer({
    required this.state,
    this.effectiveOn,
    this.charged = const [],
    this.firstFree,
    this.bookings = 0,
  });

  /// Applied, scheduled for its date, or pending an approval.
  final MemberTermState state;

  /// The date it is in force from, when the answer names it.
  final DateTime? effectiveOn;

  /// A pause: the months that stay charged in full (their first days).
  final List<DateTime> charged;

  /// A pause: the first month it frees, if any.
  final DateTime? firstFree;

  /// A pause: the member's bookings in the months it frees — they stay, and
  /// are charged as use.
  final int bookings;

  factory MemberTermAnswer.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'member term change');
    DateTime? month(String? period) =>
        period == null ? null : DateTime.parse('$period-01');
    return MemberTermAnswer(
      state: MemberTermState.fromWire(
        r.stringOrNull('state') ?? (r.isTrue('pending') ? 'pending' : null),
      ),
      effectiveOn: switch (r.stringOrNull('effective_on')) {
        final on? => DateTime.parse(on),
        null => null,
      },
      charged: [for (final p in r.strings('due')) DateTime.parse('$p-01')],
      firstFree: month(r.stringOrNull('first_free')),
      bookings: r.intOrNull('bookings_in_free_months') ?? 0,
    );
  }
}

/// A dated change the server refused: [earliest] is the first date it can
/// take.
class MemberTermDateRefused implements Exception {
  const MemberTermDateRefused(this.earliest);

  final DateTime earliest;

  @override
  String toString() => 'MemberTermDateRefused($earliest)';
}
