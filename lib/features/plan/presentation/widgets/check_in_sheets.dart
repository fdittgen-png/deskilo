// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../reservations/domain/reservation.dart';
import '../../domain/seat.dart';
import '../../../../core/time/workspace_time.dart';

/// The check-in bottom sheets of the live plan, extracted from
/// PlanScreen (#408 grew it past its length budget). Pure UI — the
/// caller reads the clock, performs the repository calls and maps
/// errors; presence gating lives in [Reservation.checkInWindowOpen].

/// Sheet on MY reservation: check out / check in / cancel, returned as
/// 'checkout' / 'checkin' / 'cancel' (null = dismissed). Outside the
/// check-in window (#408) the check-in tile is disabled and explains
/// itself — [now] must be the REAL clock, never the browsed instant.
Future<String?> showMySeatSheet(
  BuildContext context, {
  required Seat seat,
  required Reservation mine,
  required DateTime now,
}) {
  final l10n = AppLocalizations.of(context);
  // #490 — the window opens on the WORKSPACE clock.
  final opensAt = DateFormat.Hm().format(WorkspaceTime.wall(
      mine.startsAt.subtract(Reservation.checkInLeeway)));
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              seat.name.isEmpty ? (l10n?.planYourSeat ?? 'Your seat') : seat.name,
            ),
            subtitle: Text(
              '${DateFormat.Hm().format(mine.startsAt.toLocal())} – '
              '${DateFormat.Hm().format(mine.endsAt.toLocal())}',
            ),
          ),
          if (mine.status == ReservationStatus.checkedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n?.planCheckOutButton ?? 'Check out'),
              onTap: () => Navigator.of(context).pop('checkout'),
            )
          else if (mine.checkInWindowOpen(now))
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n?.planCheckInButton ?? 'Check in'),
              onTap: () => Navigator.of(context).pop('checkin'),
            )
          else
            // Outside the window (#408): the tile explains itself
            // instead of offering a check-in the server would refuse.
            ListTile(
              enabled: false,
              leading: const Icon(Icons.login),
              title: Text(l10n?.planCheckInButton ?? 'Check in'),
              subtitle: Text(
                now.isBefore(mine.startsAt)
                    ? (l10n?.planCheckInOpensAt(opensAt) ??
                        'Check-in opens at $opensAt')
                    : (l10n?.planCheckInOverError ??
                        'This reservation is over — check-in is no '
                            'longer possible.'),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: Text(
              l10n?.planCancelReservationButton ?? 'Cancel reservation',
            ),
            onTap: () => Navigator.of(context).pop('cancel'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Sheet on another member's seat for admins: check them in when they
/// are present (#408, window open) and/or OVERRULE — remove the
/// reservation entirely (#412): "the other will be removed and the user
/// and all admins/owners will be notified" (the 0007 event trigger is
/// the notification channel). Returns 'checkin' / 'remove' / null; the
/// caller performs the calls — everything is re-checked server-side.
Future<String?> showCheckInOtherSheet(
  BuildContext context, {
  required Seat seat,
  required Reservation other,
  required String name,
  required bool offerCheckIn,
}) {
  final l10n = AppLocalizations.of(context);
  final reservedBy = l10n?.planReservedBy(name) ?? 'Reserved by $name';
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(seat.name.isEmpty ? reservedBy : seat.name),
            subtitle: Text(
              '$reservedBy · '
              '${DateFormat.Hm().format(other.startsAt.toLocal())} – '
              '${DateFormat.Hm().format(other.endsAt.toLocal())}',
            ),
          ),
          if (offerCheckIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n?.planCheckInFor(name) ?? 'Check in $name'),
              onTap: () => Navigator.of(context).pop('checkin'),
            ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: Text(
              l10n?.planOverruleRemove ?? 'Remove reservation (overrule)',
            ),
            subtitle: Text(
              l10n?.planOverruleHint(name) ??
                  '$name and all admins will be notified.',
            ),
            onTap: () => Navigator.of(context).pop('remove'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
