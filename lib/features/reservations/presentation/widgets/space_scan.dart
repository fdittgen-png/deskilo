// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../../core/format/cents.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../money/domain/quota_rules.dart';
import '../../../plan/domain/desk.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/office.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/space_code.dart';
import '../../domain/walk_up_window.dart';
import '../../providers/reservation_providers.dart';
import 'booking_range_text.dart';

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

  // Resolve the code against the floor plan — a stale card (deleted
  // space) reports instead of crashing.
  final levels = await ref.read(levelsProvider.future);
  Level? level;
  Office? office;
  Desk? desk;
  Seat? seat;
  FloorPlan? plan;
  if (code.kind == SpaceKind.level) {
    level = levels.where((l) => l.id == code.id).firstOrNull;
  } else {
    for (final candidate in levels) {
      final p = await ref.read(floorPlanProvider(candidate.id).future);
      switch (code.kind) {
        case SpaceKind.office:
          office = p.offices.where((o) => o.id == code.id).firstOrNull;
        case SpaceKind.desk:
          desk = p.desks.where((d) => d.id == code.id).firstOrNull;
        case SpaceKind.seat:
          seat = p.seats.where((s) => s.id == code.id).firstOrNull;
          desk = seat == null
              ? null
              : p.desks.where((d) => d.id == seat!.deskId).firstOrNull;
        case SpaceKind.level:
          break;
      }
      if (office != null || desk != null || seat != null) {
        level = candidate;
        plan = p;
        office ??=
            p.offices.where((o) => o.id == desk?.officeId).firstOrNull;
        break;
      }
    }
  }
  if (!context.mounted) return;
  final resolved = switch (code.kind) {
    SpaceKind.level => level != null,
    SpaceKind.office => office != null,
    SpaceKind.desk => desk != null,
    SpaceKind.seat => seat != null,
  };
  if (!resolved) {
    AppSnack.error(
      context,
      l10n?.spaceScanUnknown ??
          'This code does not match any space here anymore.',
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SpaceSheet(
      kind: code.kind,
      level: level,
      office: office,
      desk: desk,
      seat: seat,
      plan: plan,
    ),
  );
}

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
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: SizedBox(
              key: const ValueKey('space-scan-camera'),
              height: 220,
              child: widget.scanBuilder!(onCode: _submit),
            ),
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
  });

  final SpaceKind kind;
  final Level? level;
  final Office? office;
  final Desk? desk;
  final Seat? seat;
  final FloorPlan? plan;

  @override
  ConsumerState<SpaceSheet> createState() => _SpaceSheetState();
}

class _SpaceSheetState extends ConsumerState<SpaceSheet> {
  bool _busy = false;

  ({DateTime start, DateTime end}) get _window => walkUpWindow(
        ref.read(bookingGranularityProvider).value ??
            BookingGranularity.flexible,
        DateTime.now(),
      );

  List<Reservation> _reservations(({DateTime start, DateTime end}) window) {
    final merged = <Reservation>[];
    for (final key in dayKeysForWindow(window.start, window.end)) {
      merged.addAll(
        ref.watch(reservationsForDayProvider(key)).value ?? const [],
      );
    }
    return merged;
  }

  Future<void> _create({
    String? seatId,
    String? officeId,
    String? levelId,
    required bool checkIn,
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
            officeId: officeId,
            levelId: levelId,
            startsAt: window.start,
            endsAt: window.end,
            checkIn: checkIn,
          );
    } catch (e, st) {
      debugPrint('space booking failed: $e\n$st');
      TraceLogger.instance
          .error('reservations', 'space booking failed',
              error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      final message = switch (e) {
        PostgrestException(:final message)
            when message.contains('not allowed to reserve a level') =>
          l10n?.levelNotAllowed ??
              'You are not allowed to reserve a whole office or level.',
        PostgrestException(:final message)
            when message.contains('reservations in that period') ||
                message.contains('already reserved') ||
                message.contains('reserved as a whole') =>
          l10n?.levelConflict ??
              'The level has reservations in that period.',
        PostgrestException(:final message)
            when message.contains(QuotaExceededError.serverSubstring) =>
          l10n?.quotaExceededError ??
              'Monthly half-day quota reached — request extra half-days '
                  'from the Money tab.',
        PostgrestException(:final message)
            when message.contains(ReservationLimitError.serverSubstring) =>
          l10n?.reservationLimitError ??
              'Reservation limit reached — you already hold the maximum '
                  'number of open reservations.',
        _ => l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      };
      AppSnack.error(context, message, replace: true);
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

    // Whole-space bookability of the scanned office/level.
    final wholeTarget = switch (widget.kind) {
      SpaceKind.office => (
          bookable: office?.bookableAsWhole ?? false,
          priceCents: office?.priceCents ?? 0,
        ),
      SpaceKind.level => (
          bookable: level?.bookableAsWhole ?? false,
          priceCents: level?.priceCents ?? 0,
        ),
      SpaceKind.desk || SpaceKind.seat => null,
    };
    final granted = me?.canReserveLevel ?? false;
    final wholeAllowed =
        wholeTarget != null && featureOn && wholeTarget.bookable && granted;
    // Visible conflicts disable the whole-space buttons up front; the
    // server re-checks (offices/levels elsewhere, series, races).
    final wholeConflict = widget.kind == SpaceKind.office
        ? seats.any(seatTaken) ||
            reservations.any((r) =>
                (r.officeId == office?.id || r.levelId == office?.levelId) &&
                r.coversRange(window.start, window.end))
        : reservations.any((r) =>
            r.levelId == level?.id &&
                r.coversRange(window.start, window.end));

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
          if (wholeAllowed) ...[
            FilledButton.icon(
              key: const ValueKey('space-checkin'),
              onPressed: _busy || wholeConflict
                  ? null
                  : () => _create(
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
              onPressed: _busy || wholeConflict
                  ? null
                  : () => _create(
                        officeId:
                            widget.kind == SpaceKind.office ? office?.id : null,
                        levelId:
                            widget.kind == SpaceKind.level ? level?.id : null,
                        checkIn: false,
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
