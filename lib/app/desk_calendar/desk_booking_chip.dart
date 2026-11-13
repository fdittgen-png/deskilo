// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — one booking drawn in a grid: a tinted region with its
// member's name and hours, a target of its own that opens the booking beside
// the grid. Its hit region is exactly what it draws, so two bookings side by
// side never share a target.
import 'package:flutter/material.dart';

import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_radius.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/booking_range_text.dart';

/// The key of the chip of booking [id].
@visibleForTesting
Key deskBookingKey(String id) => ValueKey('desk-booking-$id');

/// The hours of [r] as the booking sheet writes them.
String deskBookingRange(BuildContext context, Reservation r) =>
    bookingRangeText(
      context,
      appFormatOf(context),
      context.l10n,
      r.startsAt,
      r.endsAt,
    );

/// The member's name on [r], or '' while the names are not read.
String deskBookingWho(Map<String, String> names, Reservation r) =>
    names[r.memberId] ?? '';

/// A booking as a region of a grid.
class DeskBookingChip extends StatelessWidget {
  const DeskBookingChip({
    required this.booking,
    required this.who,
    required this.placeName,
    required this.selected,
    required this.onOpen,
    this.showHours = true,
    super.key,
  });

  final Reservation booking;
  final String who;
  final String placeName;
  final bool selected;
  final VoidCallback onOpen;

  /// Whether the line carries the hours after the name (a month cell lists
  /// names only).
  final bool showHours;

  Color _tint(ColorScheme scheme) => switch (booking.status) {
    ReservationStatus.reserved => scheme.primaryContainer,
    ReservationStatus.checkedIn => scheme.tertiaryContainer,
    ReservationStatus.completed => scheme.surfaceContainerHighest,
    ReservationStatus.cancelled ||
    ReservationStatus.released => scheme.errorContainer,
  };

  Color _ink(ColorScheme scheme) => switch (booking.status) {
    ReservationStatus.reserved => scheme.onPrimaryContainer,
    ReservationStatus.checkedIn => scheme.onTertiaryContainer,
    ReservationStatus.completed => scheme.onSurfaceVariant,
    ReservationStatus.cancelled ||
    ReservationStatus.released => scheme.onErrorContainer,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final range = deskBookingRange(context, booking);
    final label = who.isEmpty ? placeName : who;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $placeName, $range',
      excludeSemantics: true,
      child: Material(
        color: _tint(scheme),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smAll,
          side: selected
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: deskBookingKey(booking.id),
          onTap: onOpen,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                showHours ? '$label · $range' : label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: _ink(scheme)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
