// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
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
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import '../../domain/booking_error_text.dart';
import 'booking_sheet.dart';
import 'space_scan_sheet.dart';
import 'space_conflict_actions.dart';
import 'series_result_dialog.dart';
import 'space_act_sheet.dart';
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

  // #585 — the tap path joins the camera and the typed field when this
  // device can read NFC and the chair-tag feature is on (#604).
  final nfcReader = ref.read(nfcUidReaderProvider);
  final seatTagsOn = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.nfcSeatTags);
  final nfcReady = seatTagsOn && await nfcReader.isAvailable();
  if (!context.mounted) return;

  final code = await showModalBottomSheet<SpaceCode>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SpaceScanSheet(
      workspaceId: workspace.id,
      scanBuilder:
          qrScanSupported ? ref.read(qrScanWidgetBuilderProvider) : null,
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

  // #622 — a scanned WORKSTATION acts like tapping it on the kiosk:
  // straight into the shared one-sheet (action + derived period), the
  // signed-in member confirming instead of a badge.
  if (code.kind == SpaceKind.seat && seat != null) {
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
    level: level,
    office: office,
    desk: desk,
    seat: seat,
    plan: plan,
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
  Level? level,
  Office? office,
  Desk? desk,
  Seat? seat,
  FloorPlan? plan,
  ({DateTime start, DateTime end})? initialWindow,
  List<({String id, String name})> members = const [],
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
        members: members,
      ),
    );

/// The scanner: camera (injectable seam) plus a typed field — wedge
/// scanners and tests type the payload. Foreign QR contents show an
/// inline error and keep the sheet open.
// The scan sheet itself lives next door: reading a CODE and acting on a
// SPACE are different jobs, and this file only ever held both because
// one opens the other.
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
    this.members = const [],
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

  /// Members this actor may book the WHOLE SPACE for (#638): empty for
  /// everyone but an owner/delegated admin, and the presence of the
  /// list is itself the assignment right — the caller holds the roster
  /// and the gate (`bookForOthers` / `adminLevelAssign`), the sheet only
  /// offers the choice. Only `admin_create_reservation_for` scales
  /// exist server-side (seat and level), so the selector rides the LEVEL
  /// kind; a desk/office keeps booking for the actor.
  final List<({String id, String name})> members;

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
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || _busy) return;
    setState(() => _busy = true);
    final who =
        (ref.read(memberNamesProvider).value ?? const {})[subjectMemberId] ??
            '';
    try {
      await ref.read(reservationRepositoryProvider).createFor(
            workspaceId: workspace.id,
            subjectMemberId: subjectMemberId,
            levelId: levelId,
            startsAt: startsAt,
            endsAt: endsAt,
          );
    } catch (e, st) {
      debugPrint('space booking for member failed: $e\n$st');
      TraceLogger.instance.error(
          'reservations', 'space booking for member failed',
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
      l10n?.planBookedForPending(who) ?? 'Sent to $who for confirmation.',
      replace: true,
    );
    invalidateBookingData(ref);
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
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await act(reservation.id);
    } catch (e, st) {
      TraceLogger.instance
          .error('reservations', 'space $what failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        // Every rule about whether this is legal lives on the server
        // (0116); a refusal must say WHY rather than merely fail.
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

  /// The subjects the reserve picker offers (#638): myself when I hold
  /// the whole-space grant, plus every candidate the caller passed. An
  /// empty list means no selector at all — a plain member never sees one.
  List<({String id, String name})> _subjectOptions(
    AppLocalizations? l10n, {
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
        (id: me.id, name: l10n?.levelAssignMyself ?? 'Myself'),
      ...others,
    ];
  }

  /// Whole-space RESERVE (0065, field request): the same
  /// granularity-aware period picker and repetition the seat sheet
  /// offers — the configuration decides which picker shows. The
  /// server re-checks conflicts for whatever window is chosen. Since
  /// #638 the SAME sheet also carries the "For the member" selector the
  /// level rail's own sheet used to own alone.
  Future<void> _reserveSpace({
    String? deskId,
    String? officeId,
    String? levelId,
    required String name,
    required bool granted,
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
    final subjects = _subjectOptions(l10n, granted: granted);

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
        members: subjects,
        myMemberId: me?.id,
        allowSeries: allowSeries,
        allowBlocking: false,
      ),
    );
    if (choice == null || !mounted) return;

    // Assigned to somebody else: the 0079 admin path — their own
    // confirmation flow applies (#106), so no series, no check-in.
    final subjectId = choice.forMemberId;
    if (subjectId != null && subjectId != me?.id) {
      await _createFor(
        subjectMemberId: subjectId,
        levelId: levelId,
        startsAt: choice.start,
        endsAt: choice.end,
      );
      return;
    }

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

  /// Reserve-or-check-in for one free seat — since #622 the SHARED
  /// kiosk one-sheet core (action + derived period), authenticated:
  /// the member confirms instead of presenting a badge.
  Future<void> _seatActions(Seat seat) =>
      showSpaceActSheet(
        context,
        seat: seat,
        plan: widget.plan,
        title: seat.name,
      );

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
    // #638 — the caller handed a roster: this actor may ASSIGN the space
    // even without holding the personal grant (an active co-owner who is
    // not flagged admin), exactly what the deleted level sheet allowed.
    final canAssign = widget.members.isNotEmpty;
    final wholeAllowed = wholeTarget != null &&
        featureOn &&
        wholeTarget.bookable &&
        (granted || canAssign);
    // Visible conflicts disable the whole-space buttons up front; the
    // server re-checks (offices/levels elsewhere, series, races). #622
    // resolves the blocking RESERVATION (not just a bool) so the
    // conflict note can offer messaging its holder.
    final seatBlocking = reservations
        .where((r) =>
            r.seatId != null &&
            seats.any((s) => s.id == r.seatId) &&
            r.coversRange(window.start, window.end))
        .firstOrNull;
    final wholeBlocking = switch (widget.kind) {
      SpaceKind.desk => seatBlocking ??
          reservations
              .where((r) =>
                  (r.deskId == desk?.id ||
                      r.officeId == desk?.officeId ||
                      r.levelId == office?.levelId) &&
                  r.coversRange(window.start, window.end))
              .firstOrNull,
      SpaceKind.office => seatBlocking ??
          reservations
              .where((r) =>
                  (r.officeId == office?.id ||
                      r.levelId == office?.levelId ||
                      (r.deskId != null &&
                          (plan?.desks ?? const <Desk>[])
                              .any((d) => d.id == r.deskId))) &&
                  r.coversRange(window.start, window.end))
              .firstOrNull,
      _ => reservations
          .where((r) =>
              r.levelId == level?.id &&
              r.coversRange(window.start, window.end))
          .firstOrNull,
    };
    final wholeConflict = wholeBlocking != null;

    // My own live booking of exactly this space in the window. Both
    // states, and that is the fix for a field report: with `reserved`
    // alone, a level you had CHECKED INTO fell through to the conflict
    // branch below and the sheet became a dead end — it stated that the
    // space was taken, by you, and offered nothing. There was no check
    // out anywhere on it.
    final myWholeReservation = me == null
        ? null
        : reservations
            .where((r) =>
                r.memberId == me.id &&
                (r.status == ReservationStatus.reserved ||
                    r.status == ReservationStatus.checkedIn) &&
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
          Text(
            priceLine,
            // #638 — the converged sheet carries the level sheet's own
            // price line; the key travelled with it.
            key: const ValueKey('space-price-line'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (wholeTarget != null) ...[
          const SizedBox(height: 12),
          if (myWholeReservation != null) ...[
            Text(
              myWholeReservation.status == ReservationStatus.checkedIn
                  ? (l10n?.spaceYoursCheckedIn ??
                      'You are checked in here for this slot.')
                  : (l10n?.spaceYoursNow ?? 'Reserved by you for this slot.'),
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
                    _busy ? null : () => _checkOutExisting(myWholeReservation),
                icon: const Icon(Icons.logout_outlined),
                label: Text(l10n?.kioskCheckOut ?? 'Check out'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('space-checkin-mine'),
                onPressed: _busy
                    ? null
                    : () => _checkInExisting(myWholeReservation),
                icon: const Icon(Icons.login_outlined),
                label: Text(l10n?.kioskCheckIn ?? 'Check in'),
              ),
            // ...and the way to undo it. Cancel, end early and request
            // deletion each have their own rules and their own gates;
            // routing to the detail sheet is what keeps this sheet from
            // owning a second, drifting copy of them.
            SpaceConflictActions(
              blocking: myWholeReservation,
              myMemberId: me?.id,
              spaceName: title,
              busy: _busy,
            ),
          ] else if (wholeAllowed) ...[
            // Checking in seats ME here and now — that needs the
            // personal grant, never the assignment right alone (#638).
            if (granted) ...[
              FilledButton.icon(
                key: const ValueKey('space-checkin'),
                onPressed: _busy || wholeConflict
                    ? null
                    : () => _create(
                          deskId:
                              widget.kind == SpaceKind.desk ? desk?.id : null,
                          officeId: widget.kind == SpaceKind.office
                              ? office?.id
                              : null,
                          levelId:
                              widget.kind == SpaceKind.level ? level?.id : null,
                          checkIn: true,
                        ),
                icon: const Icon(Icons.login_outlined),
                label: Text(l10n?.kioskCheckIn ?? 'Check in'),
              ),
              const SizedBox(height: 8),
            ],
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
                        granted: granted,
                      ),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(l10n?.kioskReserve ?? 'Reserve'),
            ),
            if (wholeConflict) ...[
              const SizedBox(height: 8),
              Text(
                wholeBlocking.memberId == me?.id
                    ? (l10n?.spaceBlockedByYou ??
                        'You already hold this space for that period.')
                    : (l10n?.levelConflict ??
                        'The level has reservations in that period.'),
                key: const ValueKey('space-conflict'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SpaceConflictActions(
                blocking: wholeBlocking,
                myMemberId: me?.id,
                spaceName: title,
                busy: _busy,
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
        // WHERE is it? (field request) — every space sheet can jump to
        // the plan with the space in focus, closing every sheet on the
        // way so the plan is actually visible.
        if (level != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('space-show-plan'),
            icon: const Icon(Icons.map_outlined),
            label: Text(l10n?.calendarShowOnPlan ?? 'Show on plan'),
            onPressed: () {
              // #576 — the highlight matches WHAT was selected: seat,
              // table, office or the whole floor.
              ref.read(planFocusControllerProvider.notifier).setFocus(
                    PlanFocus(
                      levelId: level.id,
                      seatId: scannedSeat?.id,
                      deskId: desk?.id,
                      officeId: desk == null ? office?.id : null,
                      wholeLevel: scannedSeat == null &&
                          desk == null &&
                          office == null,
                    ),
                  );
              Navigator.of(context).popUntil((route) =>
                  route is! ModalBottomSheetRoute &&
                  route is! RawDialogRoute);
              context.go('/plan');
            },
          ),
        ],
      ],
    );
  }
}
