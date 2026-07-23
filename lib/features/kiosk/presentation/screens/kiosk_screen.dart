// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../events/providers/event_providers.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../money/domain/quota_rules.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../reservations/presentation/widgets/booking_range_text.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../device_pin.dart';

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

  /// The window an action books: the canonical full day under day-based
  /// granularity, else now → default stay (capped at the day's last slot).
  ({DateTime start, DateTime end}) _actionWindow() {
    final granularity = ref.read(bookingGranularityProvider).value ??
        BookingGranularity.flexible;
    final now = DateTime.now();
    if (granularity.isDayBased) {
      final window = HalfDayWindows.fullDay(now);
      return (start: window.start, end: window.end);
    }
    var end = now.add(const Duration(hours: 4));
    final last = DateTime(now.year, now.month, now.day, 23, 45);
    if (end.isAfter(last)) end = last;
    if (!end.isAfter(now)) end = now.add(const Duration(minutes: 15));
    return (start: now, end: end);
  }

  Future<void> _onSeatTap(Seat seat) =>
      _actionThenBadge(title: seat.name, seatId: seat.id);

  /// Whole-level path (0050): the same action → authenticate flow, with
  /// the level as the booking target.
  Future<void> _onLevelTap(Level level) => _actionThenBadge(
        title: level.name,
        levelId: level.id,
      );

  Future<void> _actionThenBadge({
    required String title,
    String? seatId,
    String? levelId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<KioskAction>(
      context: context,
      builder: (context) => SheetShell(
        title: title,
        children: [
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('kiosk-check-in'),
            onPressed: () => Navigator.of(context).pop(KioskAction.checkIn),
            icon: const Icon(Icons.login_outlined),
            label: Text(l10n?.kioskCheckIn ?? 'Check in'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('kiosk-reserve'),
            onPressed: () => Navigator.of(context).pop(KioskAction.reserve),
            icon: const Icon(Icons.event_available_outlined),
            label: Text(l10n?.kioskReserve ?? 'Reserve'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('kiosk-check-out'),
            onPressed: () => Navigator.of(context).pop(KioskAction.checkOut),
            icon: const Icon(Icons.logout_outlined),
            label: Text(l10n?.kioskCheckOut ?? 'Check out'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    await _badgeSheet(
      action,
      targetName: title,
      seatId: seatId,
      levelId: levelId,
    );
  }

  /// The badge prompt: an autofocused field a wedge scanner (or a human)
  /// types the badge code into. Submitting calls the stateless kiosk_act
  /// RPC — the code lives only in this sheet's controller and dies with it.
  Future<void> _badgeSheet(
    KioskAction action, {
    required String targetName,
    String? seatId,
    String? levelId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _KioskBadgePrompt(
        reader: ref.read(nfcUidReaderProvider),
        nfcEnabled: ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.nfcBadges),
        // Camera QR scanning (K3): the wall tablet reads the printed
        // badge with its camera — the injectable zxing seam keeps
        // tests camera-free.
        scanBuilder:
            qrScanSupported ? ref.read(qrScanWidgetBuilderProvider) : null,
        l10n: l10n,
      ),
    );
    if (token == null || token.isEmpty || !mounted) return;
    // The sheet's dispose stopped BOTH readers (NFC session + camera) —
    // the confirm step below runs with everything off (field request).

    final window = _actionWindow();

    // Identify first: resolve the badge to its member so the summary
    // names WHO is about to act — the wrong-badge guard on a shared
    // wall tablet.
    final String memberName;
    try {
      memberName =
          await ref.read(reservationRepositoryProvider).kioskIdentify(
                workspaceId: workspace.id,
                badgeToken: token,
              );
    } catch (e, st) {
      debugPrint('kiosk identify failed: $e\n$st');
      TraceLogger.instance
          .error('kiosk', 'kiosk identify failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        e is PostgrestException &&
                e.message.contains(KioskBadgeError.serverSubstring)
            ? (l10n?.kioskBadgeRejected ?? 'Badge not recognized.')
            : (l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.'),
        replace: true,
      );
      return;
    }
    if (!mounted) return;

    // The résumé: who, what, where, when — Confirm executes, Reject
    // discards. Nothing has happened yet.
    final actionLabel = switch (action) {
      KioskAction.checkIn => l10n?.kioskCheckIn ?? 'Check in',
      KioskAction.reserve => l10n?.kioskReserve ?? 'Reserve',
      KioskAction.checkOut => l10n?.kioskCheckOut ?? 'Check out',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(actionLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberName,
              key: const ValueKey('kiosk-summary-name'),
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(targetName),
            if (action != KioskAction.checkOut) ...[
              const SizedBox(height: 4),
              Text(
                bookingRangeText(l10n, window.start, window.end),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('kiosk-summary-reject'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.kioskRejectAction ?? 'Reject'),
          ),
          FilledButton(
            key: const ValueKey('kiosk-summary-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.kioskConfirmAction ?? 'Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(reservationRepositoryProvider).kioskAct(
            workspaceId: workspace.id,
            badgeToken: token,
            action: action.wireName,
            seatId: seatId,
            levelId: levelId,
            startsAt:
                action == KioskAction.checkOut ? null : window.start,
            endsAt: action == KioskAction.checkOut ? null : window.end,
          );
    } catch (e, st) {
      debugPrint('kiosk act failed: $e\n$st');
      TraceLogger.instance
          .error('kiosk', 'kiosk act failed', error: e, stackTrace: st);
      if (!mounted) return;
      final message = switch (e) {
        PostgrestException(:final message)
            when message.contains(KioskBadgeError.serverSubstring) =>
          l10n?.kioskBadgeRejected ?? 'Badge not recognized.',
        PostgrestException(:final message)
            when message.contains(ReservationLimitError.serverSubstring) =>
          l10n?.reservationLimitError ??
              'Reservation limit reached — you already hold the maximum '
                  'number of open reservations.',
        PostgrestException(:final message)
            when message.contains(QuotaExceededError.serverSubstring) =>
          l10n?.quotaExceededError ??
              'Monthly half-day quota reached — request extra half-days '
                  'from the Money tab.',
        _ => l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      };
      AppSnack.error(context, message, replace: true);
      return;
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.kioskDone ?? "Done — you're all set.",
      replace: true,
    );
    invalidateBookingData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
    final now = DateTime.now();
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
            Padding(
              padding: AppSpacing.lgAll,
              child: Row(
                children: [
                  Icon(
                    Icons.tablet_mac_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      workspace?.name ?? '',
                      key: const ValueKey('kiosk-title'),
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    l10n?.kioskTapHint ?? 'Tap a seat to check in',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            LevelChipRow(
              levels: levels,
              selectedLevelId: level.id,
              onSelected: (id) => setState(() => _levelId = id),
            ),
            // Whole-level booking at the wall (0050): tap → pick the
            // action → authenticate with the RFID/NFC card, a scanned
            // badge, or the typed code — exactly like a seat.
            if (level.bookableAsWhole &&
                ref
                    .watch(enabledFeaturesSyncProvider)
                    .contains(WorkspaceFeature.levelBooking))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('kiosk-level-button'),
                    onPressed: () => _onLevelTap(level),
                    icon: const Icon(Icons.layers_outlined),
                    label: Text(
                      l10n?.kioskLevelButton ?? 'This level',
                    ),
                  ),
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
                    onlineSeatIds: onlineSeatIdsFor(
                      plan: plan,
                      reservations: reservations,
                      members: ref.watch(workspaceMembersProvider).value ??
                          const [],
                      profiles: ref.watch(memberProfilesProvider).value ??
                          const {},
                      from: now,
                    ),
                    deskOpacity:
                        (workspace?.deskOpacity ?? 100) / 100,
                    background:
                        ref.watch(levelBackgroundProvider(level.id)).value,
                    images: {
                      for (final image in plan.images)
                        if (ref.watch(planImageProvider(image.id)).value !=
                            null)
                          image.id:
                              ref.watch(planImageProvider(image.id)).value!,
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

/// The badge prompt (0043 + 0046): type/scan the QR code, OR tap an
/// RFID/NFC card. When NFC is available a read session runs while the
/// sheet is open; the first tap pops with the tag's normalized UID —
/// which kiosk_act resolves by hash exactly like a scanned code. The code
/// never leaves this sheet.
class _KioskBadgePrompt extends StatefulWidget {
  const _KioskBadgePrompt({
    required this.reader,
    required this.nfcEnabled,
    required this.scanBuilder,
    required this.l10n,
  });

  final NfcUidReader reader;
  final bool nfcEnabled;

  /// Camera scanner embed, or null off-mobile (wedge scanners remain).
  final QrScanWidgetBuilder? scanBuilder;
  final AppLocalizations? l10n;

  @override
  State<_KioskBadgePrompt> createState() => _KioskBadgePromptState();
}

/// What the RFID path is doing, shown IN the sheet (field report: "the
/// RFID was not read" was undiagnosable at the wall — no NFC hardware,
/// NFC off in Android settings and a dead session all looked identical).
enum _NfcUiState { checking, reading, off, unsupported, failed, featureOff }

class _KioskBadgePromptState extends State<_KioskBadgePrompt> {
  final _controller = TextEditingController();
  _NfcUiState _nfc = _NfcUiState.checking;
  bool _cameraReady = false;

  /// Whether the camera scanner is mounted. Field-proven root cause: on
  /// the wall tablet the RFID tap reads fine in the registration dialog
  /// (NFC armed, NO camera) but never in this sheet with the camera
  /// streaming next to it — Samsung camera/NFC coexistence. So when NFC
  /// is ready the sheet opens in CARD mode (no camera — the exact
  /// environment registration proved working) and the QR camera is one
  /// tap away; without NFC the camera mounts directly as before.
  bool _cameraMode = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startReaders();
  }

  /// NFC first, camera second: the RFID reader-mode session must be
  /// registered before the camera pipeline spins up — starting both at
  /// once left the tap path dead on the wall tablet while the barcode
  /// still scanned (field report).
  Future<void> _startReaders() async {
    await _startNfc();
    if (mounted) setState(() => _cameraReady = true);
  }

  Future<void> _startNfc() async {
    if (!widget.nfcEnabled) {
      if (mounted) setState(() => _nfc = _NfcUiState.featureOff);
      return;
    }
    final status = await widget.reader.status();
    if (!mounted) return;
    if (status != NfcStatus.ready) {
      TraceLogger.instance.warn('kiosk', 'nfc not ready: ${status.name}');
      setState(() => _nfc = status == NfcStatus.off
          ? _NfcUiState.off
          : _NfcUiState.unsupported);
      return;
    }
    // Card mode: the tap path owns the sheet, the camera stays down.
    setState(() {
      _nfc = _NfcUiState.reading;
      _cameraMode = false;
    });
    final started =
        await widget.reader.startRead(onUid: (uid) => _submit(uid));
    if (!mounted || started) return;
    // startRead already traced the failure — surface it at the wall and
    // fall back to the camera.
    setState(() {
      _nfc = _NfcUiState.failed;
      _cameraMode = true;
    });
  }

  void _submit(String value) {
    final code = value.trim();
    if (_done || !mounted || code.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    unawaited(widget.reader.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    // Precomputed (lint: no literals inside Text with interpolation).
    final nfcProblem = switch (_nfc) {
      _NfcUiState.off => l10n?.kioskNfcOff ??
          "NFC is turned off in this tablet's Android settings — turn it "
              'on to read RFID cards.',
      _NfcUiState.unsupported => l10n?.kioskNfcUnsupported ??
          'This tablet has no NFC reader — scan the QR badge instead.',
      _NfcUiState.failed => l10n?.kioskNfcFailed ??
          'The RFID reader did not start — restart the app and try again.',
      _ => null,
    };
    return SheetShell(
      title: l10n?.kioskPresentBadge ?? 'Present your badge',
      children: [
        const SizedBox(height: 8),
        Text(
          _nfc == _NfcUiState.reading
              ? (l10n?.kioskBadgeHintNfc ??
                  'Tap your card, scan your QR, or type its code.')
              : (l10n?.kioskBadgeHint ??
                  'Scan your badge QR, or type its code.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_nfc == _NfcUiState.reading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: Icon(Icons.contactless_outlined, size: 44),
            ),
          ),
        // The RFID path explains itself when it cannot read — the
        // difference between "no hardware", "NFC off in settings" and
        // "session failed" is exactly what a wall diagnosis needs.
        if (nfcProblem != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              key: const ValueKey('kiosk-nfc-status'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mobile_off_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nfcProblem,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        // With NFC reading, the camera stays DOWN (see _cameraMode) —
        // one tap brings it up for QR badges.
        if (widget.scanBuilder != null && _cameraReady && !_cameraMode)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              key: const ValueKey('kiosk-scan-qr-button'),
              onPressed: () => setState(() => _cameraMode = true),
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: Text(
                l10n?.kioskScanQr ?? 'Scan the QR badge',
              ),
            ),
          ),
        // The camera reads the printed badge QR right in the sheet —
        // no external scanner needed on the wall tablet (K3). It mounts
        // only after the NFC session is up (see _startReaders).
        if (widget.scanBuilder != null && _cameraReady && _cameraMode) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: SizedBox(
              key: const ValueKey('kiosk-badge-camera'),
              height: 220,
              child: widget.scanBuilder!(onCode: _submit),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('kiosk-badge-field'),
          controller: _controller,
          // The camera embed owns the screen when present; the field
          // stays for wedge scanners and manual entry without popping
          // the soft keyboard over the preview.
          autofocus: widget.scanBuilder == null,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n?.kioskBadgeFieldLabel ?? 'Badge code',
          ),
          // Wedge scanners terminate with Enter — submit directly.
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('kiosk-badge-submit'),
          onPressed: () => _submit(_controller.text),
          child: Text(l10n?.kioskBadgeConfirm ?? 'Confirm'),
        ),
      ],
    );
  }
}
