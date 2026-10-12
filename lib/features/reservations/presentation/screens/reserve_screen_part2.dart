// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'reserve_screen.dart';

// #2386 — part 2 of _ReserveScreenState, split out of reserve_screen.dart so no
// file holds the whole class.
extension _ReserveScreenStatePart2 on _ReserveScreenState {

  // ── build ──

  Widget _buildImpl(BuildContext context) {
    // #182 — the hub stays alive in the shell's indexed stack, so this
    // listener survives tab switches.
    ref.listen(planFocusControllerProvider, (_, focus) {
      if (focus != null) _applyFocus(focus);
    });
    final l10n = context.l10n;
    // Watched so the chips swap once the rule resolves (#201) — flexible
    // is also the rule's default, so nothing flashes.
    final granularity = ref.watch(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final window = _effectiveWindow(granularity);

    // Closed day (#186): banner + gated booking. Watched (not the
    // read-based [_isWorkspaceOpenAt]) so the hub reacts to availability
    // edits. #1301 S4 — unknown while loading is neither open nor closed.
    final openWeekdays = ref.watch(openWeekdaysProvider).value;
    final closures = ref.watch(closureDaysProvider).value;
    final dayKnown = openWeekdays != null && closures != null;
    final dayOpen = openWeekdays != null &&
        closures != null &&
        isWorkspaceOpenOn(_selectedDay, openWeekdays, closures);
    // #814 — the legend under the controls, and closed days drawn as
    // closed in every view (not only the plan).
    final gateOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.bookingGate);
    // Keep the policies warm: the gate reads them synchronously at tap
    // time (a cold provider would judge with the defaults).
    if (gateOn) ref.watch(bookingPoliciesProvider);

    final features = ref.watch(enabledFeaturesSyncProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final member = ref.watch(myMemberProvider);
    final me = member.value;
    final policies = ref.watch(bookingPoliciesProvider);
    final endpoint = ref.watch(activeBackendProvider).value;
    final guidanceKey = features.contains(WorkspaceFeature.memberGettingStarted)
        ? gettingStartedSeenKey(installation: endpoint?.url ?? '',
            accountId: ref.watch(currentAccountIdProvider) ?? '',
            workspaceId: workspace?.id ?? '') : null;
    final levels = ref.watch(levelsProvider);
    final browsed = ref.watch(browsedLevelProvider);
    final wanted = browsed == BrowsedLevel.allLevels ? null : browsed;
    final level = levels.value?.where((l) => l.id ==
        (wanted ?? ref.watch(selectedLevelIdProvider).value)).firstOrNull ??
        levels.value?.firstOrNull;
    final plan = level == null ? null : ref.watch(floorPlanProvider(level.id));
    final spaces = level == null
        ? factOf(levels).map((list) => list.length)
        : factOf(plan!).map((p) => p.seats.length +
            p.offices.where((o) => o.bookableAsWhole).length +
            p.desks.where((d) => d.bookableAsWhole).length +
            (level.bookableAsWhole ? 1 : 0) + levels.value!.length - 1);
    final targetNames = ref.watch(targetNamesProvider).value ?? const <String, String>{};
    final facts = GettingStartedFacts(
      workspaceName: workspace?.name ?? '',
      production: workspace != null && !workspace.isDevelopment,
      membership: factOf(member).map((m) => m == null
          ? MembershipStanding.inactive : switch (m.status) {
              MemberStatus.pending => MembershipStanding.pending,
              MemberStatus.active => m.isOwner ? MembershipStanding.owner
                  : m.isAdmin ? MembershipStanding.administrator : MembershipStanding.member,
              _ => MembershipStanding.inactive,
            }),
      dayOpen: dayKnown ? Fact.ready(dayOpen)
          : ref.watch(openWeekdaysProvider).hasError || ref.watch(closureDaysProvider).hasError
              ? const Fact.offline() : const Fact.loading(),
      bookableSpaces: spaces,
      allowance: me != null && features.contains(WorkspaceFeature.bookingPolicies)
          ? factOf(policies).map((p) => BookingPolicies.allowanceFor(me.maxSimultaneousReservations, p))
          : const Fact.loading(),
      ownBooking: me == null ? const Fact.loading()
          : factOf(ref.watch(reservationsForDayProvider(dayKeyOf(_selectedDay)))).map((list) {
              final mine = list.where((r) => r.memberId == me.id &&
                  r.status != ReservationStatus.cancelled && r.status != ReservationStatus.released).toList()
                ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
              return mine.isEmpty ? null : BookingEvidence(id: mine.first.id,
                  state: mine.first.status.name, spaceName: mine.first.spaceNameFrom(targetNames));
            }),
    );

    // No own AppBar: the hub lives inside the shell (bottom bar always
    // visible); the shell's app bar carries the 'Reserve' title.
    // ReserveHubLayout owns the adaptive controls panel and view transitions.
    Widget header() {
      // ROW 1 — what you are looking at.
      final viewControls = <Widget>[
            // #1301 S2 — the time views behind one named control.
            ReserveViewMenu(
              key: const ValueKey('reserve-reserve-view-menu'),
              view: _view,
              onChanged: (view) {
                _update(() => _view = view);
                recordTaskStep(ref, RecorderActions.switchView, // #1881
                    payload: {'view_mode': view.name});
              },
              onGetStarted: gettingStartedReopen(ref, guidanceKey),
            ),
            // Map <-> list, as ONE button showing the icon of what you
            // would switch TO.
            //
            // It was a fifth segment in the toggle above until the
            // tap-target guard caught it: five icon segments squeeze to
            // 45.6dp at phone width, under the 48dp floor. And it never
            // belonged there anyway — Day/Week/Month are TIME views,
            // while map and list are two presentations of the same one.
            // A second two-segment toggle would have shown two map icons
            // in one row; this shows one, and never the one you are
            // already looking at.
            if (_view == ReserveView.plan || _view == ReserveView.list)
              IconButton(
                key: const ValueKey('reserve-seat-view-switch'),
                tooltip: _seatList
                    ? (l10n.planMapViewTooltip)
                    : (l10n.planListViewTooltip),
                icon: Icon(
                  _seatList ? Icons.map_outlined : Icons.view_list_outlined,
                ),
                onPressed: () {
                  _update(() => _view =
                      _seatList ? ReserveView.plan : ReserveView.list);
                  recordTaskStep(ref, RecorderActions.switchView, // #1865
                      payload: {'view_mode': _seatList ? 'list' : 'plan'});
                },
              ),
            // #2016 — 'Back to now': today AND the live window (a
            // hand-picked window left on today reads as live while past).
            // Only while browsing; on this row so #699's two rows hold.
            if (!_selectedDay.isAtSameMomentAs(_today) ||
                _windowStart != null)
              // A word, not a clock (that read as a time editor); the
              // full action is the tooltip and the screen-reader label.
              Tooltip(
                message: l10n.reserveBackToNow,
                child: TextButton(
                  key: const ValueKey('reserve-now-button'),
                  onPressed: () => _update(() {
                    _selectedDay = _today;
                    _windowStart = null;
                    _windowEnd = null;
                  }),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    minimumSize: const Size(0, kMinInteractiveDimension),
                  ),
                  child: Text(
                    l10n.planNowButton,
                    semanticsLabel: l10n.reserveBackToNow,
                  ),
                ),
              ),
      ];
      // ROW 2 — WHEN you are looking at it, plus how the plan draws.
      final whenControls = <Widget>[
            TextButton(
              key: const ValueKey('reserve-date-button'),
              // #699 — the default TextButton carries 16dp of padding a
              // side for a two-word label. Trimmed to 8, with the 48dp
              // minimum kept explicitly so the target never follows the
              // padding down.
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: const Size(0, kMinInteractiveDimension),
              ),
              onPressed: _pickDate,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_month_outlined, size: 18),
                const SizedBox(width: 4),
                // #711 — intl's default locale IS the member's format
                // locale now (set by appFormatProvider), so the bare
                // call is the right one; a per-site locale would
                // disagree with every other date on screen.
                Text(DateFormat.MMMd().format(_selectedDay)),
              ]),
            ),
            // Honest controls: the window chips act on Plan (state
            // filter + booking window) and Day (the window a free-row
            // tap books). Week books per tapped half, Month is an
            // overview — no chips.
            if (_view != ReserveView.week && _view != ReserveView.month)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: WindowControls(
                  key: const ValueKey('reserve-window-controls'),
                  keyPrefix: 'reserve',
                  granularity: granularity,
                  day: _selectedDay,
                  isSelected: (w) =>
                      window.start == w.start && window.end == w.end,
                  onPickWindow: (w) {
                    _update(() {
                      _windowStart = w.start;
                      _windowEnd = w.end;
                    });
                    recordTaskStep(ref, RecorderActions.selectPeriod, // #1865
                        payload: {
                          'period': periodOf(
                              startHour: WorkspaceTime.wall(w.start).hour,
                              length: w.end.difference(w.start)),
                        },
                        values: periodValues(w.start, w.end));
                  },
                  from: window.start,
                  to: window.end,
                  onPickFrom: _pickFrom,
                  onPickTo: _pickTo,
                ),
              ),
      ];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PendingBookingBanner(), // #1855 — nothing unless an answer is owed
          MotionReveal(
            child: dayOpen
                ? const SizedBox.shrink(
                    key: ValueKey('reserve-open-day'))
                : dayKnown
                    ? HelpBlocker(id: 'reserve.closed-day', child: _closedDayBanner(l10n))
                    // #1301 S4 — loading reads as loading, not as closed.
                    : const LinearProgressIndicator(
                        key: ValueKey('reserve-availability-loading'),
                        minHeight: 2),
          ),
          const MotionReveal(child: StaleAvailabilityBanner()), // #1305 S3
          HeaderControlRow(children: viewControls),
          HeaderControlRow(children: whenControls),
          if (_view != ReserveView.week && _view != ReserveView.month)
            BookingWindowSummary(window: window, today: _today,
              timezone: workspace?.timezone),
          if (gateOn)
            SeatLegend(
              showClosed: _view == ReserveView.week ||
                  _view == ReserveView.month ||
                  _view == ReserveView.day,
            ),
          // #1853 A — ONE help slot: the Get started next step (#1654), or
          // else the hub's tip carousel (#606); each gated inside.
          MotionReveal(
            child: ReserveHelpHost(
              facts: facts,
              seenKey: guidanceKey,
              onChooseTime: _pickDate, workspaceId: workspace?.id, // #1636
            ),
          ),
        ],
      );
    }
    return ReserveHubLayout(header: header(), view: _view,
      buildView: (view) => switch (view) {
        ReserveView.plan || ReserveView.list => _planView(l10n, window, dayOpen: dayOpen),
        ReserveView.day => _dayView(),
        ReserveView.week => _weekView(),
        ReserveView.month => _monthView(),
      });
  }


  /// Closed-day banner (#186 style): the workspace is not open on the
  /// selected day, so nothing below is bookable. Shared [InlineBanner]
  /// since #210.
  Widget _closedDayBanner(AppLocalizations l10n) {
    // #1196 — the banner used to state the fact and stop there, so a
    // member who opened the hub on a Sunday got a blocked plan, inert
    // chips and no way forward but the date picker, two taps away and
    // not obviously the answer. The next open day is something this
    // screen already knows.
    final next = nextOpenDay(
      // Tomorrow: today is the day being called closed.
      _selectedDay.add(const Duration(days: 1)),
      openWeekdays: ref.watch(openWeekdaysProvider).value ?? const [],
      closures: ref.watch(closureDaysProvider).value ?? const [],
    );
    final label = next == null
        ? null
        : appFormatOf(context).shortDate(
            WorkspaceTime.at(next.year, next.month, next.day, 12),
          );
    return InlineBanner(
      key: const ValueKey('reserve-closed-banner'),
      icon: Icons.event_busy,
      text: l10n.planClosedDay,
      // A workspace closed for longer than the horizon, or with no open
      // weekday at all, has nothing to point at. Then the banner says
      // only what it always said, which is the honest answer.
      actionLabel: label == null
          ? null
          : (l10n.planClosedDayShowNext(label)),
      onAction: next == null ? null : () => _selectDay(next),
    );
  }
}
