// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/seat_context.dart';
import '../../../plan/presentation/widgets/seat_accessory_row.dart';
import '../../../plan/providers/seat_context_providers.dart';
import '../../domain/reservation.dart';

/// Where is my reserved seat? (#182) Time range and status icon (same
/// formatting as the calendar row), the resolved location chain
/// "level · office · desk · seat" (level · office for whole-office
/// bookings), the seat's accessories, and a "Show on plan" jump.
///
/// Pops with the resolved [SeatContext] when the user wants the jump —
/// the caller then signals the plan tab and navigates. Extracted from the
/// calendar screen so the Reserve hub (#208) can share it (#206).
class ReservationDetailSheet extends ConsumerWidget {
  const ReservationDetailSheet({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = reservation;
    final seatId = r.seatId;
    final officeId = r.officeId;
    // Self-loading like SeatAccessoryRow: while resolving (or when the
    // target vanished) the location line is simply absent and the jump
    // button disabled — the sheet itself never blocks.
    final targetAsync = seatId != null
        ? ref.watch(seatContextProvider(seatId))
        : officeId != null
            ? ref.watch(officeContextProvider(officeId))
            : const AsyncData<SeatContext?>(null);
    final target = targetAsync.value;
    final timeFormat = DateFormat.Hm();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r.seriesId != null
                    ? Icons.repeat
                    : (r.status == ReservationStatus.checkedIn
                        ? Icons.event_seat
                        : Icons.schedule),
              ),
              title: Text(
                '${timeFormat.format(r.startsAt.toLocal())} – '
                '${timeFormat.format(r.endsAt.toLocal())}',
              ),
              subtitle: target == null ? null : Text(target.locationLine),
            ),
            if (seatId != null) SeatAccessoryRow(seatId: seatId),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.map_outlined),
              onPressed: target == null
                  ? null
                  : () => Navigator.of(context).pop(target),
              label: Text(l10n?.calendarShowOnPlan ?? 'Show on plan'),
            ),
          ],
        ),
      ),
    );
  }
}
