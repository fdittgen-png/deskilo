// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../plan/presentation/widgets/level_chip_row.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

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
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
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
    await _badgeSheet(action, seatId: seatId, levelId: levelId);
  }

  /// The badge prompt: an autofocused field a wedge scanner (or a human)
  /// types the badge code into. Submitting calls the stateless kiosk_act
  /// RPC — the code lives only in this sheet's controller and dies with it.
  Future<void> _badgeSheet(
    KioskAction action, {
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

    final window = _actionWindow();
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

    return Scaffold(
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

class _KioskBadgePromptState extends State<_KioskBadgePrompt> {
  final _controller = TextEditingController();
  bool _nfcAvailable = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startNfc();
  }

  Future<void> _startNfc() async {
    if (!widget.nfcEnabled || !await widget.reader.isAvailable()) return;
    if (!mounted) return;
    setState(() => _nfcAvailable = true);
    await widget.reader.startRead(onUid: (uid) => _submit(uid));
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
    return SheetShell(
      title: l10n?.kioskPresentBadge ?? 'Present your badge',
      children: [
        const SizedBox(height: 8),
        Text(
          _nfcAvailable
              ? (l10n?.kioskBadgeHintNfc ??
                  'Tap your card, scan your QR, or type its code.')
              : (l10n?.kioskBadgeHint ??
                  'Scan your badge QR, or type its code.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_nfcAvailable)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: Icon(Icons.contactless_outlined, size: 44),
            ),
          ),
        // The camera reads the printed badge QR right in the sheet —
        // no external scanner needed on the wall tablet (K3).
        if (widget.scanBuilder != null) ...[
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
