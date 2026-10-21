// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../domain/booking_error_text.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_repository.dart';
import '../../domain/series_preview.dart';
import '../../domain/space_code.dart';
import '../../domain/walk_up_window.dart';
import '../../domain/whole_space_blocking.dart';
import '../../providers/reservation_providers.dart';
import '../booking_gate_scope.dart';
import '../space_subjects.dart';
import 'booking_range_text.dart';
import 'booking_sheet.dart';
import 'reference_open.dart';
import 'series_preview_dialog.dart';
import 'series_result_dialog.dart';
import 'space_act_sheet.dart';
import 'space_conflict_actions.dart';
import 'space_price_line.dart';
import 'space_scan_sheet.dart';

part 'space_scan_part1.dart';

part 'space_scan_part2.dart';


class _SpaceSheetState extends ConsumerState<_SpaceSheet> {
  bool _busy = false;

  ({DateTime start, DateTime end}) get _window => walkUpWindow(
        ref.read(bookingGranularityProvider).value ??
            BookingGranularity.flexible,
        ref.read(clockProvider).now(),
        windows: ref.read(bookingWindowsProvider),
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
    final level = widget.level;
    final office = widget.office;
    final desk = widget.desk;
    final scannedSeat = widget.seat;
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

  /// The whole-space (desk, office, level) part of the sheet: my own live
  /// booking and the one action that moves it forward, or the check-in and
  /// reserve buttons with a visible conflict, or why the space is not
  /// offered (permission transparency, field request).
  List<Widget> _wholeSection(
    BuildContext context, {
    required ({bool bookable, int priceCents}) target,
    required String title,
    required String? priceLine,
    required String? myId,
    required Reservation? myWholeReservation,
    required bool allowed,
    required bool granted,
    required bool featureOn,
    required Reservation? blocking,
    required Desk? desk,
    required Office? office,
    required Level? level,
  }) {
    final l10n = context.l10n;
    return [

          const SizedBox(height: 12),
          if (myWholeReservation != null) ...[
            Text(
              myWholeReservation.status == ReservationStatus.checkedIn
                  ? (l10n.spaceYoursCheckedIn)
                  : (l10n.spaceYoursNow),
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
                label: Text(l10n.kioskCheckOut),
              )
            else
              FilledButton.icon(
                key: const ValueKey('space-checkin-mine'),
                onPressed: _busy
                    ? null
                    : () => _checkInExisting(myWholeReservation),
                icon: const Icon(Icons.login_outlined),
                label: Text(l10n.kioskCheckIn),
              ),
            // ...and the way to undo it. Cancel, end early and request
            // deletion each have their own rules and their own gates;
            // routing to the detail sheet is what keeps this sheet from
            // owning a second, drifting copy of them.
            SpaceConflictActions(
              blocking: myWholeReservation,
              myMemberId: myId,
              spaceName: title,
              busy: _busy,
            ),
          ] else if (allowed) ...[
            // Checking in seats ME here and now — that needs the
            // personal grant, never the assignment right alone (#638).
            if (granted) ...[
              FilledButton.icon(
                key: const ValueKey('space-checkin'),
                onPressed: _busy || blocking != null
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
                label: Text(l10n.kioskCheckIn),
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
                        knownPrice: priceLine,
                        granted: granted,
                      ),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(l10n.kioskReserve),
            ),
            if (blocking != null) ...[
              const SizedBox(height: 8),
              Text(
                blocking.memberId == myId
                    ? (l10n.spaceBlockedByYou)
                    : (l10n.levelConflict),
                key: const ValueKey('space-conflict'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SpaceConflictActions(
                blocking: blocking,
                myMemberId: myId,
                spaceName: title,
                busy: _busy,
              ),
            ],
          ] else ...[
            // Permission transparency (field request: "show the
            // functionalities to which the user is permitted").
            Text(
              !featureOn || !target.bookable
                  ? (l10n.spaceNotBookable)
                  : (l10n.levelNotAllowed),
              key: const ValueKey('space-not-allowed'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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

    final title = _title(plan);

    final seats = _seatsShown(widget.kind, plan, desk, office, scannedSeat);
    bool seatTaken(Seat seat) => reservations
        .any((r) => r.seatId == seat.id &&
            r.coversRange(window.start, window.end));

    final wholeTarget = _wholeTargetOf(widget.kind, desk, office, level);
    final granted = // owners/admins implicitly allowed since 0079 (#412)
        (me?.canReserveLevel ?? false) || ref.read(actsForReservationsProvider);
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
    final wholeBlocking = wholeSpaceBlocking(
      kind: widget.kind,
      plan: plan,
      reservations: reservations,
      from: window.start,
      to: window.end,
      deskId: desk?.id,
      officeId: widget.kind == SpaceKind.desk ? desk?.officeId : office?.id,
      levelId: widget.kind == SpaceKind.level ? level?.id : office?.levelId,
    );

    // My own live booking of exactly this space in the window. Both
    // states, and that is the fix for a field report: with `reserved`
    // alone, a level you had CHECKED INTO fell through to the conflict
    // branch below and the sheet became a dead end — it stated that the
    // space was taken, by you, and offered nothing. There was no check
    // out anywhere on it.
    final myWholeReservation = me == null
        ? null
        : _myLiveWholeReservation(
            widget.kind,
            reservations,
            me.id,
            window,
            deskId: desk?.id,
            officeId: office?.id,
            levelId: level?.id,
          );

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
          ..._wholeSection(
            context,
            target: wholeTarget,
            title: title,
            priceLine: priceLine,
            myId: me?.id,
            myWholeReservation: myWholeReservation,
            allowed: wholeAllowed,
            granted: granted,
            featureOn: featureOn,
            blocking: wholeBlocking,
            desk: desk,
            office: office,
            level: level,
          ),
        if (seats.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final seat in seats)
            _SeatTile(
              seat: seat,
              taken: seatTaken(seat),
              busy: _busy,
              onPick: () => _seatActions(seat),
            ),
        ],
        // WHERE is it? (field request) — every space sheet can jump to
        // the plan with the space in focus, closing every sheet on the
        // way so the plan is actually visible.
        if (level != null) ...[
          const SizedBox(height: 8),
          _ShowOnPlanButton(
            level: level,
            seat: scannedSeat,
            desk: desk,
            office: office,
          ),
        ],
      ],
    );
  }

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

}

/// The seats listed: the scanned workstation itself, the desk's own, or
/// every seat of the office's desks.
List<Seat> _seatsShown(
  SpaceKind kind,
  FloorPlan? plan,
  Desk? desk,
  Office? office,
  Seat? scannedSeat,
) {
  final seats = plan?.seats ?? const <Seat>[];
  return switch (kind) {
    SpaceKind.seat => [?scannedSeat],
    SpaceKind.desk => seats.where((s) => s.deskId == desk?.id).toList(),
    SpaceKind.office => () {
      final deskIds = (plan?.desks ?? const <Desk>[])
          .where((d) => d.officeId == office?.id)
          .map((d) => d.id)
          .toSet();
      return seats.where((s) => deskIds.contains(s.deskId)).toList();
    }(),
    SpaceKind.level => const <Seat>[],
  };
}

/// Whole-space bookability of the scanned desk/office/level (0059 added the
/// desk scale); null for a seat.
({bool bookable, int priceCents})? _wholeTargetOf(
  SpaceKind kind,
  Desk? desk,
  Office? office,
  Level? level,
) => switch (kind) {
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

/// My own live booking of exactly this space in the window. Both states, and
/// that is the fix for a field report: with `reserved` alone, a level you had
/// CHECKED INTO fell through to the conflict branch and the sheet became a
/// dead end -- it stated that the space was taken, by you, and offered
/// nothing. There was no check out anywhere on it.
Reservation? _myLiveWholeReservation(
  SpaceKind kind,
  List<Reservation> reservations,
  String myMemberId,
  ({DateTime start, DateTime end}) window, {
  String? deskId,
  String? officeId,
  String? levelId,
}) => reservations
    .where(
      (r) =>
          r.memberId == myMemberId &&
          (r.status == ReservationStatus.reserved ||
              r.status == ReservationStatus.checkedIn) &&
          r.coversRange(window.start, window.end) &&
          switch (kind) {
            SpaceKind.desk => r.deskId == deskId,
            SpaceKind.office => r.officeId == officeId,
            SpaceKind.level => r.levelId == levelId,
            SpaceKind.seat => false,
          },
    )
    .firstOrNull;

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.taken,
    required this.busy,
    required this.onPick,
  });

  final Seat seat;
  final bool taken;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('space-seat-${seat.id}'),
    contentPadding: EdgeInsets.zero,
    enabled: !taken && !busy,
    leading: Icon(
      taken ? Icons.event_busy_outlined : Icons.event_seat_outlined,
    ),
    title: Text(seat.name),
    subtitle: taken ? Text(context.l10n.spaceSeatTaken) : null,
    onTap: taken ? null : onPick,
  );
}

/// WHERE is it? (field request) -- jumps to the plan with the space in focus,
/// closing every sheet on the way so the plan is actually visible.
class _ShowOnPlanButton extends ConsumerWidget {
  const _ShowOnPlanButton({
    required this.level,
    required this.seat,
    required this.desk,
    required this.office,
  });

  final Level level;
  final Seat? seat;
  final Desk? desk;
  final Office? office;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const ValueKey('space-show-plan'),
    icon: const Icon(Icons.map_outlined),
    label: Text(context.l10n.calendarShowOnPlan),
    onPressed: () {
      // #576 -- the highlight matches WHAT was selected: seat, table, office
      // or the whole floor.
      ref
          .read(planFocusControllerProvider.notifier)
          .setFocus(
            PlanFocus(
              levelId: level.id,
              seatId: seat?.id,
              deskId: desk?.id,
              officeId: desk == null ? office?.id : null,
              wholeLevel: seat == null && desk == null && office == null,
            ),
          );
      Navigator.of(context).popUntil(
        (route) => route is! ModalBottomSheetRoute && route is! RawDialogRoute,
      );
      context.go('/plan');
    },
  );
}
