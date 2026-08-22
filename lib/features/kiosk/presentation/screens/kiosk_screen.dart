// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../reservations/domain/booking_error_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../events/providers/event_providers.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../plan/domain/level.dart';
import '../../../reservations/presentation/widgets/booking_range_text.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../../core/time/work_hours.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../widgets/kiosk_act_sheet.dart';
import '../../device_pin.dart';
import '../../../../core/time/clock.dart';

/// Server error substring when a presented badge is unknown/revoked
/// (kiosk_act, migration 0043) — pinned by test like the other guards.
abstract final class KioskBadgeError {
  static const String serverSubstring = 'badge not recognized';
}

/// The three actions a member can perform through the kiosk.
enum KioskAction {
  checkIn('check_in'),
  reserve('reserve'),
  checkOut('check_out');

  const KioskAction(this.wireName);

  /// The kiosk_act RPC's action parameter.
  final String wireName;
}

/// Wall-mounted tablet mode (migration 0043): the ONLY screen a kiosk
/// account ever sees (the router locks it here). Shows the live floor
/// plan; tapping a seat offers check-in / reserve / check-out, each
/// completed by presenting a member badge — typed by a wedge barcode
/// scanner (they act as keyboards) or entered manually. The badge is sent
/// straight to the stateless kiosk_act RPC and never stored, so the
/// member is "signed out" the moment the operation finishes.
class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  Timer? _minuteTick;
  String? _levelId;

  @override
  void initState() {
    super.initState();
    // Wall displays live forever — keep seat states following the clock.
    _minuteTick =
        Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    // Lockdown (field request): confirmed kiosk mode owns the pad —
    // hide the system bars and pin the app so nothing else can be
    // opened. Leaving kiosk mode = restarting the pad.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(KioskDevicePin.pin());
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(KioskDevicePin.unpin());
    super.dispose();
  }

  /// Whether the workspace is closed TODAY (open weekdays + closure
  /// days) — surfaced up front on the kiosk instead of letting a full
  /// flow run into a server rejection at the very end (field report).
  bool _closedToday() {
    final now = ref.read(clockProvider).now();
    final open = ref.read(openWeekdaysProvider).value;
    if (open != null && !open.contains(now.weekday)) return true;
    final closures = ref.read(closureDaysProvider).value ?? const [];
    return closures.any((c) =>
        c.day.year == now.year &&
        c.day.month == now.month &&
        c.day.day == now.day);
  }

  Future<void> _onSeatTap(Seat seat) =>
      _act(title: seat.name, seatId: seat.id);

  /// Whole-level path (0050): the same one-sheet flow, with the level
  /// as the booking target.
  Future<void> _onLevelTap(Level level) => _act(
        title: level.name,
        levelId: level.id,
      );

  /// The WHOLE flow (field report: "as few operations as possible"):
  /// one sheet — action preselected to Check in, the window derived
  /// from the settings, badge reader live — and the badge executes
  /// immediately. Happy path: tap the seat, present the badge. Done.
  Future<void> _act({
    required String title,
    String? seatId,
    String? levelId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    if (_closedToday()) {
      AppSnack.error(
        context,
        l10n?.kioskClosedToday ??
            'The workspace is closed today — check-in and reservations '
                'are not possible.',
        replace: true,
      );
      return;
    }
    final request = await showKioskActSheet(
      context,
      targetName: title,
      granularity: ref.read(bookingGranularityProvider).value ??
          BookingGranularity.flexible,
      now: ref.read(clockProvider).now(),
      reader: ref.read(nfcUidReaderProvider),
      nfcEnabled: ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.nfcBadges),
      // Camera QR scanning (K3): the wall tablet reads the printed
      // badge with its camera — the injectable zxing seam keeps tests
      // camera-free.
      scanBuilder:
          qrScanSupported ? ref.read(qrScanWidgetBuilderProvider) : null,
    );
    if (request == null || !mounted) return;
    // The sheet's dispose stopped BOTH readers (NFC session + camera).

    // A reservation made standing at the kiosk can start checked in —
    // one badge presentation covers both.
    final effective =
        request.action == KioskAction.reserve && request.checkInNow
            ? KioskAction.checkIn
            : request.action;
    final booksWindow = request.action != KioskAction.checkOut;

    // Identify + act in one go: the badge IS the confirmation. The
    // success card below names WHO acted — the wrong-badge guard
    // without an extra mandatory tap.
    final String memberName;
    try {
      memberName =
          await ref.read(reservationRepositoryProvider).kioskIdentify(
                workspaceId: workspace.id,
                badgeToken: request.badgeToken,
              );
      await ref.read(reservationRepositoryProvider).kioskAct(
            workspaceId: workspace.id,
            badgeToken: request.badgeToken,
            action: effective.wireName,
            seatId: seatId,
            levelId: levelId,
            startsAt: booksWindow ? request.start : null,
            endsAt: booksWindow ? request.end : null,
          );
    } catch (e, st) {
      debugPrint('kiosk act failed: $e\n$st');
      TraceLogger.instance
          .error('kiosk', 'kiosk act failed', error: e, stackTrace: st);
      if (!mounted) return;
      // #430: bookingErrorText is THE mapper; kiosk cases stay.
      final message = switch (e) {
        PostgrestException(:final message)
            when message.contains(KioskBadgeError.serverSubstring) =>
          l10n?.kioskBadgeRejected ?? 'Badge not recognized.',
        PostgrestException(:final message)
            when message.contains('not checked in') =>
          l10n?.kioskNotCheckedIn ??
              'No active check-in found — the plan may have just updated.',
        _ => bookingErrorText(
            l10n,
            e,
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
      };
      AppSnack.error(context, message, replace: true);
      return;
    }
    if (!mounted) return;
    invalidateBookingData(ref);

    // The receipt: who, what, where, until when — self-dismissing, so
    // the next member finds a clean wall.
    final actionLabel = request.action == KioskAction.reserve &&
            effective == KioskAction.checkIn
        ? (l10n?.kioskReserveAndCheckIn ?? 'Reserve & check in')
        : switch (request.action) {
            KioskAction.checkIn => l10n?.kioskCheckIn ?? 'Check in',
            KioskAction.reserve => l10n?.kioskReserve ?? 'Reserve',
            KioskAction.checkOut => l10n?.kioskCheckOut ?? 'Check out',
          };
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => _KioskSuccessCard(
        actionLabel: actionLabel,
        memberName: memberName,
        targetName: title,
        rangeText: booksWindow
            ? bookingRangeText(l10n, request.start, request.end)
            : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // #430: no shell on kiosk devices — arm realtime here.
    ref.watch(realtimeInvalidatorProvider);
    // #446: same out-of-shell rule for the ambient working day — the
    // walk-up windows this screen books derive from it.
    WorkHours.install(ref.watch(workHoursProvider).value);
    // #519 — keep the granularity warm: the period step reads it
    // synchronously when a seat is tapped.
    ref.watch(bookingGranularityProvider);
    // Closed-day inputs: WATCH so the banner appears once they load
    // (and flips at midnight with the minute tick).
    ref.watch(openWeekdaysProvider);
    ref.watch(closureDaysProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final levels = ref.watch(levelsProvider).value;
    if (levels == null) {
      return const Scaffold(body: LoadingView());
    }
    if (levels.isEmpty) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.map_outlined,
          title:
              l10n?.planNoLevels ?? 'The workspace has no floor plan yet.',
        ),
      );
    }
    final level =
        levels.where((l) => l.id == _levelId).firstOrNull ?? levels.first;
    final planAsync = ref.watch(floorPlanProvider(level.id));
    final now = ref.read(clockProvider).now();
    final reservations =
        ref.watch(reservationsForDayProvider(dayKeyOf(now))).value ??
            const [];
    final names = ref.watch(memberNamesProvider).value ?? const {};

    // canPop:false — the back button/gesture never leaves kiosk mode.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
          children: [
            // ONE header row (field report: three stacked rows — title,
            // level chips, "This level" — ate a third of a small wall
            // tablet). Title, chips, the level button and the hint share
            // a single 48dp line; the plan gets the rest.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tablet_mac_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      workspace?.name ?? '',
                      key: const ValueKey('kiosk-title'),
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Scrolls when tight; renders nothing with one level.
                  Expanded(
                    flex: 2,
                    child: LevelChipRow(
                      levels: levels,
                      selectedLevelId: level.id,
                      onSelected: (id) => setState(() => _levelId = id),
                    ),
                  ),
                  // Whole-level booking at the wall (0050): tap → pick
                  // the action → authenticate with the RFID/NFC card, a
                  // scanned badge, or the typed code — like a seat.
                  if (level.bookableAsWhole &&
                      ref
                          .watch(enabledFeaturesSyncProvider)
                          .contains(WorkspaceFeature.levelBooking))
                    Padding(
                      padding:
                          const EdgeInsets.only(right: AppSpacing.md),
                      child: OutlinedButton.icon(
                        key: const ValueKey('kiosk-level-button'),
                        onPressed: () => _onLevelTap(level),
                        icon: const Icon(Icons.layers_outlined),
                        label: Text(
                          l10n?.kioskLevelButton ?? 'This level',
                        ),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      l10n?.kioskTapHint ?? 'Tap a seat to check in',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            // Closed today (open weekdays / closure days): say it UP
            // FRONT — the settings gate the whole kiosk, not the last
            // step of a finished flow.
            if (_closedToday())
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: InlineBanner(
                  key: const ValueKey('kiosk-closed-banner'),
                  icon: Icons.event_busy_outlined,
                  text: l10n?.kioskClosedToday ??
                      'The workspace is closed today — check-in and '
                          'reservations are not possible.',
                ),
              ),
            Expanded(
              child: switch (planAsync) {
                AsyncData(value: final plan) => PlanCanvas(
                    paintKey: const ValueKey('kiosk-plan-canvas'),
                    plan: plan,
                    // Live "now" occupancy — a wall display's one job.
                    seatStates: seatStatesFor(
                      plan: plan,
                      reservations: reservations,
                      myMemberId: null,
                      from: now,
                    ),
                    // #575 — the wall display answers the same glance:
                    // served / running / still ahead today.
                    seatDayPhases: seatDayPhasesFor(
                      plan: plan,
                      reservations: reservations,
                      at: now,
                    ),
                    seatLabels: {
                      for (final seat in plan.seats)
                        seat.id: occupantLabelFor(
                          plan: plan,
                          seat: seat,
                          reservations: reservations,
                          names: names,
                          from: now,
                        ),
                    },
                    // #462: whole-space bookings mark the room/table
                    // itself on the wall display too.
                    spaceOverlays: spaceOverlaysFor(
                      plan: plan,
                      reservations: reservations,
                      names: names,
                      myMemberId: null,
                      from: now,
                    ),
                    onlineSeatIds: onlineSeatIdsFor(
                      plan: plan,
                      reservations: reservations,
                      members: ref.watch(workspaceMembersProvider).value ??
                          const [],
                      profiles: ref.watch(memberProfilesProvider).value ??
                          const {},
                      from: now,
                      now: now,
                    ),
                    deskOpacity:
                        (workspace?.deskOpacity ?? 100) / 100,
                    background:
                        ref.watch(levelBackgroundProvider(level.id)).value,
                    images: {
                      for (final image in plan.images)
                        // Single watch per image (perf audit): the double watch
                        // subscribed twice per image on every rebuild.
                        image.id: ?ref.watch(planImageProvider(image.id)).value,
                    },
                    onSeatTap: _onSeatTap,
                  ),
                AsyncError() => Center(
                    child: Text(
                      l10n?.workspaceGenericError ??
                          'Something went wrong. Please try again.',
                    ),
                  ),
                _ => const LoadingView(),
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The self-dismissing receipt: who, what, where, until when — big
/// enough to verify the badge resolved to the right person, gone in a
/// few seconds so the next member finds a clean wall. Tap anywhere to
/// dismiss sooner.
class _KioskSuccessCard extends StatefulWidget {
  const _KioskSuccessCard({
    required this.actionLabel,
    required this.memberName,
    required this.targetName,
    required this.rangeText,
  });

  final String actionLabel;
  final String memberName;
  final String targetName;
  final String? rangeText;

  @override
  State<_KioskSuccessCard> createState() => _KioskSuccessCardState();
}

class _KioskSuccessCardState extends State<_KioskSuccessCard> {
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _dismiss = Timer(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = widget.rangeText;
    return AlertDialog(
      key: const ValueKey('kiosk-success-card'),
      icon: Icon(
        Icons.check_circle_outline,
        size: 44,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(widget.actionLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.memberName,
            key: const ValueKey('kiosk-summary-name'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(widget.targetName),
          if (rangeText != null) ...[
            const SizedBox(height: 4),
            Text(
              rangeText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
