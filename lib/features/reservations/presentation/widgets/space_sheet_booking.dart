// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/booking_error_text.dart';
import '../../domain/reservation_repository.dart';
import '../../domain/series_preview.dart';
import '../../domain/space_bookability.dart';
import '../../providers/reservation_providers.dart';
import 'booking_sheet.dart';
import 'series_preview_dialog.dart';
import 'series_result_dialog.dart';

/// #2494 — the space sheet's NEW whole-space bookings: check in now,
/// reserve a period (with repetition), or assign the space to another
/// member. The sheet owns the busy flag and the repository; this class
/// owns the routine around each write — busy-guard, call, report what the
/// server said, close, refresh.
class SpaceSheetBooking {
  const SpaceSheetBooking({
    required this.context,
    required this.ref,
    required this.repository,
    required this.isBusy,
    required this.setBusy,
    required this.window,
  });

  /// The sheet's own context: a success closes the sheet.
  final BuildContext context;
  final WidgetRef ref;
  final ReservationRepository repository;
  final bool Function() isBusy;
  final ValueSetter<bool> setBusy;

  /// The walk-up window, read when a booking starts.
  final ({DateTime start, DateTime end}) Function() window;

  /// Books [ids] for myself — checked in now when [checkIn], else for
  /// [startsAt]..[endsAt] (the walk-up window by default).
  Future<void> create(
    WholeSpaceIds ids, {
    required bool checkIn,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || isBusy()) return;
    setBusy(true);
    final window = this.window();
    try {
      await repository.create(
            workspaceId: workspace.id,
            deskId: ids.deskId,
            officeId: ids.officeId,
            levelId: ids.levelId,
            startsAt: startsAt ?? window.start,
            endsAt: endsAt ?? window.end,
            checkIn: checkIn,
          );
    } on Object catch (e, st) {
      debugPrint('space booking failed: $e\n$st');
      TraceLogger.instance
          .error('reservations', 'space booking failed',
              error: e, stackTrace: st);
      if (!context.mounted) return;
      setBusy(false);
      // Shared mapper (maintainability audit): one switch for every
      // booking surface instead of a drifting paste per screen.
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n.workspaceGenericError,
        ),
        replace: true,
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n.kioskDone,
      replace: true,
    );
    invalidateBookingData(ref);
  }

  /// Books the whole space FOR another member (#638, the level sheet's
  /// own 0050 behavior): `admin_create_reservation_for` re-checks the
  /// assignment right, and the subject confirms it themselves (#106) —
  /// so the snack says "sent", not "done".
  Future<void> _createFor({
    required String subjectMemberId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || isBusy()) return;
    setBusy(true);
    final who =
        (ref.read(memberNamesProvider).value ?? const {})[subjectMemberId] ??
            '';
    try {
      await repository.createFor(
            workspaceId: workspace.id,
            subjectMemberId: subjectMemberId,
            levelId: levelId,
            startsAt: startsAt,
            endsAt: endsAt,
          );
    } on Object catch (e, st) {
      debugPrint('space booking for member failed: $e\n$st');
      TraceLogger.instance.error(
          'reservations', 'space booking for member failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      setBusy(false);
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n.workspaceGenericError,
        ),
        replace: true,
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n.planBookedForPending(who),
      replace: true,
    );
    invalidateBookingData(ref);
  }

  /// Whole-space RESERVE (0065, field request): the same
  /// granularity-aware period picker and repetition the seat sheet
  /// offers — the configuration decides which picker shows. The
  /// server re-checks conflicts for whatever window is chosen. Since
  /// #638 the SAME sheet also carries the "For the member" selector the
  /// level rail's own sheet used to own alone ([subjects]; empty for a
  /// plain member). [initial] seeds the picker.
  Future<void> reserve(
    WholeSpaceIds ids, {
    required String name,
    String? knownPrice,
    String? levelName,
    required List<({String id, String name})> subjects,
    required ({DateTime start, DateTime end}) initial,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || isBusy()) return;
    final granularity =
        ref.read(bookingGranularityProvider).value ??
            BookingGranularity.flexible;
    final me = ref.read(myMemberProvider).value;
    final allowSeries = ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.seriesBooking);

    final choice = await showAppSheet<BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BookingSheet(
        seatName: name,
        now: ref.read(clockProvider).now(),
        timezone: workspace.timezone,
        resourcePriceLabel: knownPrice,
        resourceContext: [workspace.name, ?levelName],
        start: initial.start,
        initialEnd: initial.end,
        cap: null,
        capped: false,
        granularity: granularity,
        walkUp: false,
        fixedEnd: granularity.isDayBased,
        members: subjects,
        myMemberId: me?.id,
        allowSeries: allowSeries,
      ),
    );
    if (choice == null || !context.mounted) return;

    // Assigned to somebody else: the 0079 admin path — their own
    // confirmation flow applies (#106), so no series, no check-in.
    final subjectId = choice.forMemberId;
    if (subjectId != null && subjectId != me?.id) {
      await _createFor(
        subjectMemberId: subjectId,
        levelId: ids.levelId,
        startsAt: choice.start,
        endsAt: choice.end,
      );
      return;
    }

    if (choice.pattern == null) {
      await create(
        ids,
        checkIn: false,
        startsAt: choice.start,
        endsAt: choice.end,
      );
      return;
    }
    await _series(ids, workspace.id, choice);
  }

  /// A repeated reservation: #2575 — the dates that would fail are named
  /// before anything books.
  Future<void> _series(
    WholeSpaceIds ids,
    String workspaceId,
    BookingChoice choice,
  ) async {
    final l10n = context.l10n;
    final book = await confirmSeriesPreview(
      context,
      () => ref.read(seriesPreviewerProvider),
      SeriesAsk(
        workspaceId: workspaceId,
        deskId: ids.deskId,
        officeId: ids.officeId,
        levelId: ids.levelId,
        firstStart: choice.start,
        firstEnd: choice.end,
        pattern: choice.pattern!,
        until: choice.until!,
      ),
    );
    if (!book || !context.mounted) return;
    setBusy(true);
    final SeriesResult result;
    try {
      result = await repository.createSeries(
            workspaceId: workspaceId,
            deskId: ids.deskId,
            officeId: ids.officeId,
            levelId: ids.levelId,
            firstStart: choice.start,
            firstEnd: choice.end,
            pattern: choice.pattern!,
            until: choice.until!,
          );
    } on Object catch (e, st) {
      TraceLogger.instance.error('reservations', 'space series failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      setBusy(false);
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n.workspaceGenericError,
        ),
        replace: true,
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    invalidateBookingData(ref);
    await showSeriesResultDialog(context, result);
  }
}
