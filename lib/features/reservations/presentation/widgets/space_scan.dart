// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/settings/booking_windows.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/booking_error_text.dart';
import '../../domain/reservation.dart';
import '../../domain/space_bookability.dart';
import '../../domain/space_code.dart';
import '../../domain/walk_up_window.dart';
import '../../providers/reservation_providers.dart';
import '../booking_gate_scope.dart';
import '../space_subjects.dart';
import 'booking_range_text.dart';
import 'reference_open.dart';
import 'space_act_sheet.dart';
import 'space_price_line.dart';
import 'space_scan_sheet.dart';
import 'space_sheet_booking.dart';
import 'space_sheet_tiles.dart';
import 'space_whole_section.dart';

/// The scan-to-book entry (field request): scan a desk/office/level QR
/// card → the space sheet shows exactly the actions this member is
/// permitted to take (reserve / check in now). Whole-office and
/// whole-level bookings require the whole-space feature, the owner's
/// bookable flag AND the member's personal grant — the server re-checks
/// everything.
Future<void> scanSpace(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;

  // #585 — the tap path joins the camera and the typed field when this
  // device can read NFC and the chair-tag feature is on (#604).
  final nfcReader = ref.read(nfcUidReaderProvider);
  final seatTagsOn = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.nfcSeatTags);
  final nfcReady = seatTagsOn && await nfcReader.isAvailable();
  if (!context.mounted) return;

  final code = await showAppSheet<SpaceCode>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SpaceScanSheet(
      workspaceId: workspace.id,
      scanBuilder:
          qrScanSupported ? ref.read(qrScanWidgetBuilderProvider) : null,
      explainNoCamera: kIsWeb,
      l10n: l10n,
      nfc: nfcReady ? nfcReader : null,
      seatIdForUid: (uid) => ref
          .read(floorPlanRepositoryProvider)
          .seatIdForNfcUid(workspace.id, uid),
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
      l10n.spaceScanUnknown,
    );
    return;
  }
  final desk = resolved.desk;
  final seat = resolved.seat;
  final plan = resolved.plan;

  // #622 — a scanned WORKSTATION acts like tapping it on the kiosk:
  // straight into the shared one-sheet (action + derived period), the
  // signed-in member confirming instead of a badge.
  if (code.kind == SpaceKind.seat && seat != null) {
    // #814 — parity with the kiosk: a closed day refuses up front, not
    // at the end of a full sheet (the guide promised "a scan behaves
    // like the kiosk"; this is where it did not).
    final gate = bookingGateOf(ref);
    if (gate != null && !gate.dayOpen(gate.now)) {
      AppSnack.info(
        context,
        l10n.kioskClosedToday,
        replace: true,
      );
      return;
    }
    await showSpaceActSheet(
      context,
      seat: seat,
      plan: plan,
      title: desk == null ? seat.name : '${seat.name} · ${desk.name}',
    );
    return;
  }

  await showSpaceSheet(
    context,
    kind: code.kind,
    space: resolved,
    // #687 — an admin who SCANS a room's card gets the same
    // assignment picker as one who double-taps it on the plan.
    members: spaceAssignmentCandidates(ref),
  );
}

/// Opens the whole-space sheet for an ALREADY-RESOLVED target — the
/// scan flow above, the plan canvases' double-tap (field request:
/// double-tapping a table or a room/level on the plan reserves it, or
/// checks in when it is already reserved) AND, since #638, the level
/// rail's layers icon. That last one used to open a SECOND sheet with
/// the assignment dropdown but no period picker and no series; the two
/// converged here rather than each keeping half the capability.
Future<void> showSpaceSheet(
  BuildContext context, {
  required SpaceKind kind,
  required ResolvedSpace space,
  ({DateTime start, DateTime end})? initialWindow,
  List<({String id, String name})> members = const [],
}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SpaceSheet(
        kind: kind,
        space: space,
        initialWindow: initialWindow,
        members: members,
      ),
    );

/// The scanner: camera (injectable seam) plus a typed field — wedge
/// scanners and tests type the payload. Foreign QR contents show an
/// inline error and keep the sheet open.
class _SpaceSheet extends ConsumerStatefulWidget {
  const _SpaceSheet({
    required this.kind,
    required this.space,
    this.initialWindow,
    this.members = const [],
  });

  final SpaceKind kind;

  /// The scanned target's pieces.
  final ResolvedSpace space;

  /// The window the opener was browsing (hub date strip / plan
  /// scrubber): seeds the reserve picker so "reserve for the day I am
  /// looking at" works — a scan defaults to today's walk-up window.
  final ({DateTime start, DateTime end})? initialWindow;

  /// Members this actor may book the WHOLE SPACE for (#638): empty for
  /// everyone but an owner/delegated admin, and the presence of the
  /// list is itself the assignment right — the caller holds the roster
  /// and the gate (`bookForOthers` / `adminLevelAssign`), the sheet only
  /// offers the choice. Only `admin_create_reservation_for` scales
  /// exist server-side (seat and level), so the selector rides the LEVEL
  /// kind; a desk/office keeps booking for the actor.
  final List<({String id, String name})> members;

  @override
  ConsumerState<_SpaceSheet> createState() => _SpaceSheetState();
}

class _SpaceSheetState extends ConsumerState<_SpaceSheet> {
  bool _busy = false;

  ({DateTime start, DateTime end}) get _window => walkUpWindow(
        ref.read(bookingGranularityProvider).value ??
            BookingGranularity.flexible,
        ref.read(clockProvider).now(),
        windows: ref.read(bookingWindowsProvider),
      );

  void _setBusy(bool busy) => setState(() => _busy = busy);

  /// The new whole-space bookings, written through the sheet's busy flag.
  SpaceSheetBooking get _booking => SpaceSheetBooking(
        context: context,
        ref: ref,
        repository: ref.read(reservationRepositoryProvider),
        isBusy: () => _busy,
        setBusy: _setBusy,
        window: () => _window,
      );

  /// The subjects the reserve picker offers (#638): myself when I hold
  /// the whole-space grant, plus every candidate the caller passed. An
  /// empty list means no selector at all — a plain member never sees one.
  List<({String id, String name})> _subjectOptions(
    AppLocalizations l10n, {
    required bool granted,
  }) {
    final me = ref.read(myMemberProvider).value;
    // Only the LEVEL scale exists on `admin_create_reservation_for`.
    if (me == null || widget.kind != SpaceKind.level) {
      return const <({String id, String name})>[];
    }
    final others = [
      for (final m in widget.members)
        if (m.id != me.id) m,
    ];
    if (others.isEmpty) return const <({String id, String name})>[];
    return [
      if (granted)
        (id: me.id, name: l10n.levelAssignMyself),
      ...others,
    ];
  }

  /// The sheet's title: the scanned space's name (a double tap may open the
  /// sheet without the plan or the level, both are found from the office).
  String _title(FloorPlan? plan) {
    final level = widget.space.level;
    final office = widget.space.office;
    final desk = widget.space.desk;
    final scannedSeat = widget.space.seat;
    return switch (widget.kind) {
      SpaceKind.level => level?.name ?? '',
      // #1273 — a level's only room is named by the level.
      // A double tap may open this sheet without the plan or the level:
      // both are found from the office's own level.
      SpaceKind.office => office == null
          ? ''
          : (plan ?? ref.read(floorPlanProvider(office.levelId)).value)
                  ?.officeContextName(office,
                      levelName: level?.name ?? levelNameOf(ref, office.levelId),
                      byLevel: namesSingleRoomsByLevel(ref)) ??
              office.name,
      SpaceKind.desk => desk?.name ?? '',
      // The workstation card names seat AND desk — several tables can
      // share seat letters.
      SpaceKind.seat => desk == null
          ? (scannedSeat?.name ?? '')
          : '${scannedSeat?.name ?? ''} · ${desk.name}',
    };
  }

  /// Checks in to MY existing reservation of this space (field
  /// request: an already-reserved table/room must check in, not sit
  /// behind a disabled "conflict" button — my own reservation IS the
  /// conflict).
  /// Checking IN to a booking of mine, and checking OUT of it, are the
  /// same routine with a different verb — busy-guard, call, report what
  /// the server said, close, refresh. They were written twice; one of
  /// the two would eventually stop reporting refusals the way the other
  /// does, which on this sheet reads as "nothing happened".
  Future<void> _actOnExisting(
    Reservation reservation, {
    required Future<void> Function(String id) act,
    required String what,
  }) async {
    final l10n = context.l10n;
    if (_busy) return;
    _setBusy(true);
    try {
      await act(reservation.id);
    } on Object catch (e, st) {
      TraceLogger.instance
          .error('reservations', 'space $what failed', error: e, stackTrace: st);
      if (!mounted) return;
      _setBusy(false);
      AppSnack.error(
        context,
        // Every rule about whether this is legal lives on the server
        // (0116); a refusal must say WHY rather than merely fail.
        bookingErrorText(
          l10n,
          e,
          l10n.workspaceGenericError,
        ),
        replace: true,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n.kioskDone,
      replace: true,
    );
    // The plan behind this sheet is now stale.
    invalidateBookingData(ref);
  }

  Future<void> _checkInExisting(Reservation reservation) => _actOnExisting(
        reservation,
        act: (id) => ref.read(reservationRepositoryProvider).checkIn(id),
        what: 'check-in',
      );

  /// Ending a live whole-space check-in from the same sheet that started
  /// it — the affordance whose absence made this sheet a dead end.
  Future<void> _checkOutExisting(Reservation reservation) => _actOnExisting(
        reservation,
        act: (id) => ref.read(reservationRepositoryProvider).checkOut(id),
        what: 'check-out',
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(myMemberProvider).value;
    final featureOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.levelBooking);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final window = _window;

    // The scanned target's pieces.
    final level = widget.space.level;
    final office = widget.space.office;

    final title = _title(widget.space.plan);

    final granted = // owners/admins implicitly allowed since 0079 (#412)
        (me?.canReserveLevel ?? false) || ref.read(actsForReservationsProvider);
    // #638 — the caller handed a roster: this actor may ASSIGN the space
    // even without holding the personal grant (an active co-owner who is
    // not flagged admin), exactly what the deleted level sheet allowed.
    final space = SpaceBookability.of(
      kind: widget.kind,
      space: widget.space,
      reservations: reservationsAcrossWindow(ref, window.start, window.end),
      window: window,
      myMemberId: me?.id,
      rights: (
        granted: granted,
        canAssign: widget.members.isNotEmpty,
        featureOn: featureOn,
      ),
    );
    final wholeTarget = space.wholeTarget;

    final priceLine = wholeTarget != null && wholeTarget.priceCents > 0
        ? '${centsToMajor(wholeTarget.priceCents)} '
            '${workspace?.currencyCode ?? ''} / '
            '${l10n.levelPriceLabel}'
        : null;

    return SheetShell(
      title: title,
      children: [
        const SizedBox(height: 4),
        Text(
          bookingRangeText(context, appFormatOf(context), l10n, window.start, window.end),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SpacePriceLine(
          workspaceId: workspace?.id,
          priceLine: priceLine,
          officeId: widget.kind == SpaceKind.office ? office?.id : null,
        ),
        if (wholeTarget != null)
          ...SpaceWholeSection(
            bookability: space,
            title: title,
            myId: me?.id,
            busy: _busy,
            onCheckInExisting: _checkInExisting,
            onCheckOutExisting: _checkOutExisting,
            onCheckInNow: () => _booking.create(space.ids, checkIn: true),
            onReserve: () => _booking.reserve(
              space.ids,
              name: title,
              knownPrice: priceLine,
              levelName: level?.name,
              subjects: _subjectOptions(l10n, granted: granted),
              initial: widget.initialWindow ?? _window,
            ),
          ).children(context),
        if (space.seats.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final seat in space.seats)
            SpaceSeatTile(
              seat: seat,
              taken: space.seatTaken(seat),
              busy: _busy,
              onPick: () => _seatActions(seat),
            ),
        ],
        // WHERE is it? (field request) — every space sheet can jump to
        // the plan with the space in focus, closing every sheet on the
        // way so the plan is actually visible.
        if (level != null) ...[
          const SizedBox(height: 8),
          SpaceShowOnPlanButton(levelId: level.id, space: widget.space),
        ],
      ],
    );
  }

  /// Reserve-or-check-in for one free seat — since #622 the SHARED
  /// kiosk one-sheet core (action + derived period), authenticated:
  /// the member confirms instead of presenting a badge.
  Future<void> _seatActions(Seat seat) =>
      showSpaceActSheet(
        context,
        seat: seat,
        plan: widget.space.plan,
        title: seat.name,
      );
}
