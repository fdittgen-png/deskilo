// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/domain/booking_error_text.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/seat.dart';
import 'check_in_sheets.dart';

/// The admin actions on ANOTHER member's seat, extracted from PlanScreen
/// (length budget): the sheet (check in while present, #408; overrule —
/// remove with notification, #412) plus the repository calls and error
/// mapping. The server re-checks authorization, window and state.
Future<void> runAdminSeatActions(
  BuildContext context,
  WidgetRef ref, {
  required Seat seat,
  required Reservation other,
  required String name,
  required bool offerCheckIn,
  required int? stepMinutes,
}) async {
  final l10n = AppLocalizations.of(context);
  final action = await showCheckInOtherSheet(
    context,
    seat: seat,
    other: other,
    name: name,
    offerCheckIn: offerCheckIn,
  );
  if (action == null || !context.mounted) return;
  final repo = ref.read(reservationRepositoryProvider);
  try {
    switch (action) {
      case 'checkin':
        await repo.checkIn(other.id);
      case 'remove':
        // Overrule (#412): the cancel event notifies the displaced
        // member and every admin (0007 trigger).
        await repo.cancel(other.id);
    }
  } catch (e, st) {
    debugPrint('admin $action on other failed: $e\n$st');
    TraceLogger.instance.error('plan', 'admin $action on other failed',
        error: e, stackTrace: st);
    if (!context.mounted) return;
    AppSnack.error(
      context,
      bookingErrorText(
        l10n,
        e,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        stepMinutes: stepMinutes,
      ),
      replace: true,
    );
    return;
  }
  if (action == 'remove' && context.mounted) {
    AppSnack.success(
      context,
      l10n?.planOverruleDone(name) ??
          'Reservation removed — $name was notified.',
      replace: true,
    );
  }
  invalidateBookingData(ref);
}
