// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — New booking at the desk: a side panel (K3) opened by a
// free cell of the grid, or by N, with the place and the time filled in from
// the cell. It is the booking sheet the Reserve hub uses — the same
// granularity, repeat, book-for and refusal rules — in the task surface, and
// the instant the grid resolved to is the one the booking command receives.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../core/trace/trace_logger.dart';
import '../../core/ui/adaptive/task_surface.dart';
import '../../core/ui/app_snack.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/reservations/application/book_seat.dart';
import '../../features/reservations/application/booking_recovery.dart';
import '../../features/reservations/domain/booking_error_text.dart';
import '../../features/reservations/presentation/booking_feedback.dart';
import '../../features/reservations/presentation/widgets/booking_recovery_sheet.dart';
import '../../features/reservations/presentation/widgets/booking_sheet.dart';
import '../../features/reservations/presentation/widgets/series_preview_dialog.dart';
import '../../features/reservations/presentation/widgets/series_result_dialog.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_booking_form.dart';
import 'desk_calendar.dart';
import 'desk_calendar_actions.dart';

/// The key of the New booking panel.
@visibleForTesting
const Key deskNewBookingKey = ValueKey('desk-new-booking');

/// The key of the panel's place choice.
const Key _deskNewBookingPlaceKey = ValueKey('desk-new-booking-place');

/// What a cell asks New booking for: the places the panel offers, the one
/// clicked, its day (and the instant a day grid named), and when the next
/// booking of a place begins so the window never runs into it.
typedef DeskNewBooking = ({
  List<DeskPlace> seats,
  DeskPlace place,
  DateTime day,
  DateTime? at,
  DateTime? Function(DeskPlace place, DateTime from) capOf,
});

/// Opens New booking as a side panel and books what it returns.
Future<void> showDeskNewBooking(
  BuildContext context,
  WidgetRef ref,
  DeskNewBooking ask,
) async {
  final form = DeskBookingForm.read(ref, ask.day, ask.at);
  if (form == null) return;
  // The place the panel ended on: the choice itself does not carry it.
  final chosen = ValueNotifier<DeskPlace>(ask.place);
  final choice = await showTask<BookingChoice>(
    context,
    size: TaskSize.standard,
    sessionKey: deskNewBookingKey,
    builder: (_) => _DeskNewBookingPanel(
      seats: ask.seats,
      chosen: chosen,
      sheetOf: (context, p) =>
          form.sheetOf(context, p, ask.capOf(p, form.windowOf(p).start)),
    ),
  );
  final booked = chosen.value;
  chosen.dispose();
  if (choice == null || !context.mounted) return;
  // The choice belongs to the workspace the panel opened for.
  if (ref.read(currentWorkspaceProvider).value?.id != form.workspaceId) return;
  await _book(
    context,
    ref,
    choice,
    workspaceId: form.workspaceId,
    myMemberId: form.myMemberId,
    seat: booked,
  );
}

/// The panel: the place choice over the booking sheet.
class _DeskNewBookingPanel extends StatefulWidget {
  const _DeskNewBookingPanel({
    required this.seats,
    required this.chosen,
    required this.sheetOf,
  });

  final List<DeskPlace> seats;
  final ValueNotifier<DeskPlace> chosen;
  final Widget Function(BuildContext context, DeskPlace place) sheetOf;

  @override
  State<_DeskNewBookingPanel> createState() => _DeskNewBookingPanelState();
}

class _DeskNewBookingPanelState extends State<_DeskNewBookingPanel> {
  DeskPlace get _place => widget.chosen.value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      key: deskNewBookingKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.calendarDeskNew),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: _deskNewBookingPlaceKey,
              initialValue: _place.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.calendarDeskColumnPlace),
              items: [
                for (final s in widget.seats)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (id) => setState(
                () => widget.chosen.value = widget.seats.firstWhere(
                  (s) => s.id == id,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            widget.sheetOf(context, _place),
          ],
        ),
      ),
    );
  }
}

/// What the panel's choice asked for, and what the server answered.
Future<void> _book(
  BuildContext context,
  WidgetRef ref,
  BookingChoice choice, {
  required String workspaceId,
  required String? myMemberId,
  required DeskPlace seat,
}) async {
  final l10n = context.l10n;
  if (choice.block) return;
  final ask = ownSeriesAsk(choice, workspaceId, seat.id, myMemberId);
  if (!await confirmSeriesPreview(
        context,
        () => ref.read(seriesPreviewerProvider),
        ask,
      ) ||
      !context.mounted) {
    return;
  }
  try {
    final outcome = await bookFromDesk(
      ref,
      (
        workspaceId: workspaceId,
        seatId: seat.id,
        start: choice.start,
        end: choice.end,
        checkIn: choice.walkUp || choice.checkInNow,
        forMemberId: choice.forMemberId,
        pattern: choice.pattern,
        until: choice.until,
      ),
      myMemberId: myMemberId,
    );
    if (!context.mounted) return;
    switch (outcome) {
      case SentForConfirmation(:final subjectMemberId):
        AppSnack.success(
          context,
          l10n.planBookedForPending(
            (ref.read(memberNamesProvider).value ?? const {})[subjectMemberId] ?? '', // empty-ok: a missing name is blank, not invented
          ),
          replace: true,
        );
      case Booked(:final checkedIn, :final start, :final end):
        announceBooking(
          context,
          l10n,
          checkedIn: checkedIn,
          start: start,
          end: end,
          spaceName: seat.name,
          now: ref.read(clockProvider).now(),
        );
      case SeriesBooked(:final result):
        await showSeriesResultDialog(context, result);
    }
  } on BookingIntentNotSaved catch (e, st) {
    TraceLogger.instance.warn('calendar', 'desk booking intent not saved',
        error: e, stackTrace: st);
    if (context.mounted) {
      AppSnack.error(context, bookingRecoveryNotSavedText(l10n), replace: true);
    }
    return;
  } on BookingOutcomeUnknown catch (e, st) {
    TraceLogger.instance.warn('calendar', 'desk booking answer lost; intent kept',
        error: e, stackTrace: st);
    if (context.mounted) {
      await showBookingRecoverySheet(context, ref, e.intent, spaceName: seat.name);
    }
    return;
  } on Object catch (e, st) {
    TraceLogger.instance.error('calendar', 'desk booking failed',
        error: e, stackTrace: st);
    if (context.mounted) {
      AppSnack.error(
        context,
        bookingErrorText(l10n, e, l10n.reserveBookingFailed),
        replace: true,
      );
    }
    return;
  }
  if (context.mounted) invalidateBookingData(ref);
}
