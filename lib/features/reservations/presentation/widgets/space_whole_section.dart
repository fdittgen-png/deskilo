// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/reservation.dart';
import '../../domain/space_bookability.dart';
import 'space_conflict_actions.dart';

/// The whole-space (desk, office, level) part of the space sheet: my own
/// live booking and the one action that moves it forward, or the check-in
/// and reserve buttons with a visible conflict, or why the space is not
/// offered (permission transparency, field request).
///
/// #2494 — the rows the sheet spreads into its own column, so the sheet's
/// layout is unchanged; the decision comes from [SpaceBookability].
class SpaceWholeSection {
  const SpaceWholeSection({
    required this.bookability,
    required this.title,
    required this.myId,
    required this.busy,
    required this.onCheckInExisting,
    required this.onCheckOutExisting,
    required this.onCheckInNow,
    required this.onReserve,
  });

  final SpaceBookability bookability;

  /// The space's name, for the conflict actions.
  final String title;
  final String? myId;
  final bool busy;
  final void Function(Reservation reservation) onCheckInExisting;
  final void Function(Reservation reservation) onCheckOutExisting;
  final VoidCallback onCheckInNow;
  final VoidCallback onReserve;

  /// The section's rows, starting with its own gap.
  List<Widget> children(BuildContext context) {
    final myWholeReservation = bookability.myWholeReservation;
    final target = bookability.wholeTarget!;
    return [
      const SizedBox(height: 12),
      if (myWholeReservation != null)
        ..._myWholeActions(context, myWholeReservation)
      else if (bookability.allowed)
        ..._wholeOffer(context)
      else
        // Permission transparency (field request: "show the
        // functionalities to which the user is permitted").
        Text(
          !bookability.rights.featureOn || !target.bookable
              ? (context.l10n.spaceNotBookable)
              : (context.l10n.levelNotAllowed),
          key: const ValueKey('space-not-allowed'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ];
  }

  /// My own live booking of the space: the one action that moves it
  /// forward, whichever state it is in, and the way to undo it.
  List<Widget> _myWholeActions(
    BuildContext context,
    Reservation myWholeReservation,
  ) {
    final l10n = context.l10n;
    return [
            Text(
              myWholeReservation.status == ReservationStatus.checkedIn
                  ? (l10n.spaceYoursCheckedIn)
                  : (l10n.spaceYoursNow),
              key: const ValueKey('space-yours'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // The one action that moves this booking forward, whichever
            // state it is in. Offering "check in" to a booking already
            // checked in is what made the sheet unusable.
            if (myWholeReservation.status == ReservationStatus.checkedIn)
              FilledButton.icon(
                key: const ValueKey('space-checkout-mine'),
                onPressed:
                    busy ? null : () => onCheckOutExisting(myWholeReservation),
                icon: const Icon(Icons.logout_outlined),
                label: Text(l10n.kioskCheckOut),
              )
            else
              FilledButton.icon(
                key: const ValueKey('space-checkin-mine'),
                onPressed: busy
                    ? null
                    : () => onCheckInExisting(myWholeReservation),
                icon: const Icon(Icons.login_outlined),
                label: Text(l10n.kioskCheckIn),
              ),
            // ...and the way to undo it. Cancel, end early and request
            // deletion each have their own rules and their own gates;
            // routing to the detail sheet is what keeps this sheet from
            // owning a second, drifting copy of them.
            SpaceConflictActions(
              blocking: myWholeReservation,
              myMemberId: myId,
              spaceName: title,
              busy: busy,
            ),
    ];
  }

  /// The space is offered: check in (with the personal grant) and
  /// reserve, and the visible conflict when someone holds it.
  List<Widget> _wholeOffer(BuildContext context) {
    final l10n = context.l10n;
    final blocking = bookability.blocking;
    return [
            // Checking in seats ME here and now — that needs the
            // personal grant, never the assignment right alone (#638).
            if (bookability.rights.granted) ...[
              FilledButton.icon(
                key: const ValueKey('space-checkin'),
                onPressed: busy || blocking != null ? null : onCheckInNow,
                icon: const Icon(Icons.login_outlined),
                label: Text(l10n.kioskCheckIn),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              key: const ValueKey('space-reserve'),
              // A visible conflict only blocks the NOW-based check-in:
              // the reserve picker can target any other day/period —
              // the server re-checks whatever is chosen (0065).
              onPressed: busy ? null : onReserve,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(l10n.kioskReserve),
            ),
            if (blocking != null) ...[
              const SizedBox(height: 8),
              Text(
                blocking.memberId == myId
                    ? (l10n.spaceBlockedByYou)
                    : (l10n.levelConflict),
                key: const ValueKey('space-conflict'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SpaceConflictActions(
                blocking: blocking,
                myMemberId: myId,
                spaceName: title,
                busy: busy,
              ),
            ],
    ];
  }
}
