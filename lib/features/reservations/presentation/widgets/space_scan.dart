// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/desk.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/office.dart';
import '../../../plan/domain/seat.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import '../../domain/booking_error_text.dart';
import 'booking_sheet.dart';
import 'series_result_dialog.dart';
import '../../domain/space_code.dart';
import 'reference_open.dart';
import '../../domain/walk_up_window.dart';
import '../../providers/reservation_providers.dart';
import 'booking_range_text.dart';
import '../../../../core/time/clock.dart';

/// The scan-to-book entry (field request): scan a desk/office/level QR
/// card → the space sheet shows exactly the actions this member is
/// permitted to take (reserve / check in now). Whole-office and
/// whole-level bookings require the whole-space feature, the owner's
/// bookable flag AND the member's personal grant — the server re-checks
/// everything.
Future<void> scanSpace(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;

  final code = await showModalBottomSheet<SpaceCode>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SpaceScanSheet(
      workspaceId: workspace.id,
      scanBuilder:
          qrScanSupported ? ref.read(qrScanWidgetBuilderProvider) : null,
      l10n: l10n,
    ),
  );
  if (code == null || !context.mounted) return;

  // Resolve the code against the floor plan — the shared walk message
  // references use too (#523); a stale card reports instead of
  // crashing.
  final resolved = await resolveSpaceById(ref, code.kind, code.id);
  if (!context.mounted) return;
  if (resolved == null) {
    AppSnack.error(
      context,
      l10n?.spaceScanUnknown ??
          'This code does not match any space here anymore.',
    );
    return;
  }
  final level = resolved.level;
  final office = resolved.office;
  final desk = resolved.desk;
  final seat = resolved.seat;
  final plan = resolved.plan;

  await showSpaceSheet(
    context,
    kind: code.kind,
    level: level,
    office: office,
    desk: desk,
    seat: seat,
    plan: plan,
  );
}

/// Opens the whole-space sheet for an ALREADY-RESOLVED target — the
/// scan flow above, and the plan canvases' double-tap (field request:
/// double-tapping a table or a room/level on the plan reserves it, or
/// checks in when it is already reserved).
Future<void> showSpaceSheet(
  BuildContext context, {
  required SpaceKind kind,
  Level? level,
  Office? office,
  Desk? desk,
  Seat? seat,
  FloorPlan? plan,
  ({DateTime start, DateTime end})? initialWindow,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SpaceSheet(
        kind: kind,
        level: level,
        office: office,
        desk: desk,
        seat: seat,
        plan: plan,
        initialWindow: initialWindow,
      ),
    );

/// The scanner: camera (injectable seam) plus a typed field — wedge
/// scanners and tests type the payload. Foreign QR contents show an
/// inline error and keep the sheet open.
class SpaceScanSheet extends StatefulWidget {
  const SpaceScanSheet({
    super.key,
    required this.workspaceId,
    required this.scanBuilder,
    required this.l10n,
  });

  final String workspaceId;
  final QrScanWidgetBuilder? scanBuilder;
  final AppLocalizations? l10n;

  @override
  State<SpaceScanSheet> createState() => _SpaceScanSheetState();
}

class _SpaceScanSheetState extends State<SpaceScanSheet> {
  final _controller = TextEditingController();
  bool _invalid = false;
  bool _done = false;

  void _submit(String raw) {
    if (_done || !mounted || raw.trim().isEmpty) return;
    final code = SpaceCodeCodec.decode(raw);
    if (code == null || code.workspaceId != widget.workspaceId) {
      setState(() => _invalid = true);
      return;
    }
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SheetShell(
      title: l10n?.spaceScanTitle ?? 'Scan a space code',
      children: [
        const SizedBox(height: 8),
        Text(
          l10n?.spaceScanHint ??
              'Point the camera at a desk, office or level card — or '
                  'type its code.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (widget.scanBuilder != null) ...[
          const SizedBox(height: 12),
          // Shared camera box with the lens FLIP button (field request).
          ScanCameraBox(
            cameraKey: const ValueKey('space-scan-camera'),
            onCode: _submit,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('space-scan-field'),
          controller: _controller,
          autofocus: widget.scanBuilder == null,
          decoration: InputDecoration(
            labelText: l10n?.spaceScanField ?? 'Code',
            errorText: _invalid
                ? (l10n?.spaceScanInvalid ??
                    'Not a space code of this workspace.')
                : null,
          ),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('space-scan-submit'),
          onPressed: () => _submit(_controller.text),
          child: Text(l10n?.kioskBadgeConfirm ?? 'Confirm'),
        ),
      ],
    );
  }
}

/// The scanned space's actions, filtered to what THIS member may do —
/// walk-up semantics: today's window (canonical day under day-based
/// granularity, now→+4h otherwise), reserve or check in on the spot.
class SpaceSheet extends ConsumerStatefulWidget {
  const SpaceSheet({
    super.key,
    required this.kind,
    this.level,
    this.office,
    this.desk,
    this.seat,
    this.plan,
    this.initialWindow,
  });

  final SpaceKind kind;
  final Level? level;
  final Office? office;
  final Desk? desk;
  final Seat? seat;
  final FloorPlan? plan;

  /// The window the opener was browsing (hub date strip / plan
  /// scrubber): seeds the reserve picker so "reserve for the day I am
  /// looking at" works — a scan defaults to today's walk-up window.
  final ({DateTime start, DateTime end})? initialWindow;

  @override
  ConsumerState<SpaceSheet> createState() => _SpaceSheetState();
}

class _SpaceSheetState extends ConsumerState<SpaceSheet> {
  bool _busy = false;

  ({DateTime start, DateTime end}) get _window => walkUpWindow(
        ref.read(bookingGranularityProvider).value ??
            BookingGranularity.flexible,
        ref.read(clockProvider).now(),
      );

  List<Reservation> _reservations(({DateTime start, DateTime end}) window) =>
      reservationsAcrossWindow(ref, window.start, window.end);

  Future<void> _create({
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required bool checkIn,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || _busy) return;
    setState(() => _busy = true);
    final window = _window;
    try {
      await ref.read(reservationRepositoryProvider).create(
            workspaceId: workspace.id,
            seatId: seatId,
            deskId: deskId,
            officeId: officeId,
            levelId: levelId,
            startsAt: startsAt ?? window.start,
            endsAt: endsAt ?? window.end,
            checkIn: checkIn,
          );
    } catch (e, st) {
      debugPrint('space booking failed: $e\n$st');
      TraceLogger.instance
          .error('reservations', 'space booking failed',
              error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      // Shared mapper (maintainability audit): one switch for every
      // booking surface instead of a drifting paste per screen.
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.kioskDone ?? "Done — you're all set.",
      replace: true,
    );
    invalidateBookingData(ref);
  }

  /// Checks in to MY existing reservation of this space (field
  /// request: an already-reserved table/room must check in, not sit
  /// behind a disabled "conflict" button — my own reservation IS the
  /// conflict).
  Future<void> _checkInExisting(Reservation reservation) async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .checkIn(reservation.id);
    } catch (e, st) {
      TraceLogger.instance.error('reservations', 'space check-in failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n?.kioskDone ?? "Done — you're all set.",
      replace: true,
    );
    invalidateBookingData(ref);
  }

  /// Whole-space RESERVE (0065, field request): the same
  /// granularity-aware period picker and repetition the seat sheet
  /// offers — the configuration decides which picker shows. The
  /// server re-checks conflicts for whatever window is chosen.
  Future<void> _reserveSpace({
    String? deskId,
    String? officeId,
    String? levelId,
    required String name,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || _busy) return;
    final granularity =
        ref.read(bookingGranularityProvider).value ??
            BookingGranularity.flexible;
    final me = ref.read(myMemberProvider).value;
    final allowSeries = ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.seriesBooking);
    final initial = widget.initialWindow ?? _window;

    final choice = await showModalBottomSheet<BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BookingSheet(
        seatName: name,
        start: initial.start,
        initialEnd: initial.end,
        cap: null,
        capped: false,
        granularity: granularity,
        walkUp: false,
        fixedEnd: granularity.isDayBased,
        members: const [],
        myMemberId: me?.id,
        allowSeries: allowSeries,
        allowBlocking: false,
      ),
    );
    if (choice == null || !mounted) return;

    if (choice.pattern == null) {
      await _create(
        deskId: deskId,
        officeId: officeId,
        levelId: levelId,
        checkIn: false,
        startsAt: choice.start,
        endsAt: choice.end,
      );
      return;
    }
    setState(() => _busy = true);
    final SeriesResult result;
    try {
      result = await ref.read(reservationRepositoryProvider).createSeries(
            workspaceId: workspace.id,
            deskId: deskId,
            officeId: officeId,
            levelId: levelId,
            firstStart: choice.start,
            firstEnd: choice.end,
            pattern: choice.pattern!,
            until: choice.until!,
          );
    } catch (e, st) {
      TraceLogger.instance.error('reservations', 'space series failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        bookingErrorText(
          l10n,
          e,
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    invalidateBookingData(ref);
    await showSeriesResultDialog(context, result);
  }

  /// Reserve-or-check-in picker for one free seat (the kiosk action
  /// idiom, without the badge — the member is signed in).
  Future<void> _seatActions(Seat seat) async {
    final l10n = AppLocalizations.of(context);
    final checkIn = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(seat.name),
        children: [
          SimpleDialogOption(
            key: const ValueKey('space-act-checkin'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.kioskCheckIn ?? 'Check in'),
          ),
          SimpleDialogOption(
            key: const ValueKey('space-act-reserve'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.kioskReserve ?? 'Reserve'),
          ),
        ],
      ),
    );
    if (checkIn == null || !mounted) return;
    await _create(seatId: seat.id, checkIn: checkIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(myMemberProvider).value;
    final featureOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.levelBooking);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final window = _window;
    final reservations = _reservations(window);

    // The scanned target's pieces.
    final level = widget.level;
    final office = widget.office;
    final desk = widget.desk;
    final scannedSeat = widget.seat;
    final plan = widget.plan;

    final title = switch (widget.kind) {
      SpaceKind.level => level?.name ?? '',
      SpaceKind.office => office?.name ?? '',
      SpaceKind.desk => desk?.name ?? '',
      // The workstation card names seat AND desk — several tables can
      // share seat letters.
      SpaceKind.seat => desk == null
          ? (scannedSeat?.name ?? '')
          : '${scannedSeat?.name ?? ''} · ${desk.name}',
    };

    // Seats shown: the scanned workstation itself, the desk's own, or
    // every seat of the office's desks.
    final seats = switch (widget.kind) {
      SpaceKind.seat => [?scannedSeat],
      SpaceKind.desk => (plan?.seats ?? const <Seat>[])
          .where((s) => s.deskId == desk?.id)
          .toList(),
      SpaceKind.office => () {
          final deskIds = (plan?.desks ?? const <Desk>[])
              .where((d) => d.officeId == office?.id)
              .map((d) => d.id)
              .toSet();
          return (plan?.seats ?? const <Seat>[])
              .where((s) => deskIds.contains(s.deskId))
              .toList();
        }(),
      SpaceKind.level => const <Seat>[],
    };
    bool seatTaken(Seat seat) => reservations
        .any((r) => r.seatId == seat.id &&
            r.coversRange(window.start, window.end));

    // Whole-space bookability of the scanned desk/office/level (0059
    // added the desk scale).
    final wholeTarget = switch (widget.kind) {
      SpaceKind.desk => (
          bookable: desk?.bookableAsWhole ?? false,
          priceCents: desk?.priceCents ?? 0,
        ),
      SpaceKind.office => (
          bookable: office?.bookableAsWhole ?? false,
          priceCents: office?.priceCents ?? 0,
        ),
      SpaceKind.level => (
          bookable: level?.bookableAsWhole ?? false,
          priceCents: level?.priceCents ?? 0,
        ),
      SpaceKind.seat => null,
    };
    final granted = // owners/admins implicitly allowed since 0079 (#412)
        (me?.canReserveLevel ?? false) || (me?.canAdminister ?? false);
    final wholeAllowed =
        wholeTarget != null && featureOn && wholeTarget.bookable && granted;
    // Visible conflicts disable the whole-space buttons up front; the
    // server re-checks (offices/levels elsewhere, series, races).
    final wholeConflict = switch (widget.kind) {
      SpaceKind.desk => seats.any(seatTaken) ||
          reservations.any((r) =>
              (r.deskId == desk?.id ||
                  r.officeId == desk?.officeId ||
                  r.levelId == office?.levelId) &&
              r.coversRange(window.start, window.end)),
      SpaceKind.office => seats.any(seatTaken) ||
          reservations.any((r) =>
              (r.officeId == office?.id ||
                  r.levelId == office?.levelId ||
                  (r.deskId != null &&
                      (plan?.desks ?? const <Desk>[])
                          .any((d) => d.id == r.deskId))) &&
              r.coversRange(window.start, window.end)),
      _ => reservations.any((r) =>
          r.levelId == level?.id &&
              r.coversRange(window.start, window.end)),
    };

    // My own live reservation of exactly this space in the window: the
    // sheet then offers CHECK IN to it instead of a disabled conflict.
    final myWholeReservation = me == null
        ? null
        : reservations
            .where((r) =>
                r.memberId == me.id &&
                r.status == ReservationStatus.reserved &&
                r.coversRange(window.start, window.end) &&
                switch (widget.kind) {
                  SpaceKind.desk => r.deskId == desk?.id,
                  SpaceKind.office => r.officeId == office?.id,
                  SpaceKind.level => r.levelId == level?.id,
                  SpaceKind.seat => false,
                })
            .firstOrNull;

    final priceLine = wholeTarget != null && wholeTarget.priceCents > 0
        ? '${centsToMajor(wholeTarget.priceCents)} '
            '${workspace?.currencyCode ?? ''} / '
            '${l10n?.levelPriceLabel ?? 'Price per half-day'}'
        : null;

    return SheetShell(
      title: title,
      children: [
        const SizedBox(height: 4),
        Text(
          bookingRangeText(l10n, window.start, window.end),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (priceLine != null) ...[
          const SizedBox(height: 4),
          Text(priceLine, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (wholeTarget != null) ...[
          const SizedBox(height: 12),
          if (myWholeReservation != null) ...[
            Text(
              l10n?.spaceYoursNow ?? 'Reserved by you for this slot.',
              key: const ValueKey('space-yours'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('space-checkin-mine'),
              onPressed: _busy
                  ? null
                  : () => _checkInExisting(myWholeReservation),
              icon: const Icon(Icons.login_outlined),
              label: Text(l10n?.kioskCheckIn ?? 'Check in'),
            ),
          ] else if (wholeAllowed) ...[
            FilledButton.icon(
              key: const ValueKey('space-checkin'),
              onPressed: _busy || wholeConflict
                  ? null
                  : () => _create(
                        deskId:
                            widget.kind == SpaceKind.desk ? desk?.id : null,
                        officeId:
                            widget.kind == SpaceKind.office ? office?.id : null,
                        levelId:
                            widget.kind == SpaceKind.level ? level?.id : null,
                        checkIn: true,
                      ),
              icon: const Icon(Icons.login_outlined),
              label: Text(l10n?.kioskCheckIn ?? 'Check in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('space-reserve'),
              // A visible conflict only blocks the NOW-based check-in:
              // the reserve picker can target any other day/period —
              // the server re-checks whatever is chosen (0065).
              onPressed: _busy
                  ? null
                  : () => _reserveSpace(
                        deskId:
                            widget.kind == SpaceKind.desk ? desk?.id : null,
                        officeId:
                            widget.kind == SpaceKind.office ? office?.id : null,
                        levelId:
                            widget.kind == SpaceKind.level ? level?.id : null,
                        name: title,
                      ),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(l10n?.kioskReserve ?? 'Reserve'),
            ),
            if (wholeConflict) ...[
              const SizedBox(height: 8),
              Text(
                l10n?.levelConflict ??
                    'The level has reservations in that period.',
                key: const ValueKey('space-conflict'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ] else ...[
            // Permission transparency (field request: "show the
            // functionalities to which the user is permitted").
            Text(
              !featureOn || !wholeTarget.bookable
                  ? (l10n?.spaceNotBookable ??
                      'This space is not set up for whole-space '
                          'reservations.')
                  : (l10n?.levelNotAllowed ??
                      'You are not allowed to reserve a whole office or '
                          'level.'),
              key: const ValueKey('space-not-allowed'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
        if (seats.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final seat in seats)
            ListTile(
              key: ValueKey('space-seat-${seat.id}'),
              contentPadding: EdgeInsets.zero,
              enabled: !seatTaken(seat) && !_busy,
              leading: Icon(
                seatTaken(seat)
                    ? Icons.event_busy_outlined
                    : Icons.event_seat_outlined,
              ),
              title: Text(seat.name),
              subtitle: seatTaken(seat)
                  ? Text(l10n?.spaceSeatTaken ?? 'Taken')
                  : null,
              onTap: seatTaken(seat) ? null : () => _seatActions(seat),
            ),
        ],
      ],
    );
  }
}
