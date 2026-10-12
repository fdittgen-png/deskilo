// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'space_scan.dart';

// #2386 — part 1 of _SpaceSheetState, split out of space_scan.dart so no
// file holds the whole class.
extension _SpaceSheetStatePart1 on _SpaceSheetState {

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
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || _busy) return;
    _update(() => _busy = true);
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
    } on Object catch (e, st) {
      debugPrint('space booking failed: $e\n$st');
      TraceLogger.instance
          .error('reservations', 'space booking failed',
              error: e, stackTrace: st);
      if (!mounted) return;
      _update(() => _busy = false);
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
    if (!mounted) return;
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
    if (workspace == null || _busy) return;
    _update(() => _busy = true);
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
    } on Object catch (e, st) {
      debugPrint('space booking for member failed: $e\n$st');
      TraceLogger.instance.error(
          'reservations', 'space booking for member failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      _update(() => _busy = false);
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
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      l10n.planBookedForPending(who),
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
    final l10n = context.l10n;
    if (_busy) return;
    _update(() => _busy = true);
    try {
      await act(reservation.id);
    } on Object catch (e, st) {
      TraceLogger.instance
          .error('reservations', 'space $what failed', error: e, stackTrace: st);
      if (!mounted) return;
      _update(() => _busy = false);
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
    String? knownPrice,
  }) async {
    final l10n = context.l10n;
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

    final choice = await showAppSheet<BookingChoice>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BookingSheet(
        seatName: name,
        now: ref.read(clockProvider).now(),
        timezone: workspace.timezone,
        resourcePriceLabel: knownPrice,
        resourceContext: [workspace.name, ?widget.level?.name],
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
    _update(() => _busy = true);
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
    } on Object catch (e, st) {
      TraceLogger.instance.error('reservations', 'space series failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      _update(() => _busy = false);
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
}
