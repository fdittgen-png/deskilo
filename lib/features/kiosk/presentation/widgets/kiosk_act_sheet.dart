// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../reservations/domain/walk_up_window.dart';
import '../../../reservations/presentation/widgets/booking_range_text.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../screens/kiosk_screen.dart' show KioskAction;

/// Everything one badge presentation carries out of the sheet: the
/// action, the window it books (ignored for check-out), whether a
/// begun reservation starts checked in, and the badge token itself.
typedef KioskActRequest = ({
  KioskAction action,
  DateTime start,
  DateTime end,
  bool checkInNow,
  String badgeToken,
});

/// THE kiosk sheet (field report: "far too long, too complicated"):
/// ONE surface instead of three. Tap a seat → this sheet opens with
/// **Check in** preselected, the period ALREADY DERIVED from the
/// workspace settings (granularity + working hours, clamped to now),
/// the rule it derives from spelled out, and the badge reader LIVE at
/// the bottom. The happy path is exactly two operations: tap the seat,
/// present the badge. Switching to Reserve / Check out, or another
/// period, is one optional tap each — and the badge always completes
/// the act immediately; there is no separate confirm step.
Future<KioskActRequest?> showKioskActSheet(
  BuildContext context, {
  required String targetName,
  required BookingGranularity granularity,
  required DateTime now,
  required NfcUidReader reader,
  required bool nfcEnabled,
  QrScanWidgetBuilder? scanBuilder,
}) =>
    showModalBottomSheet<KioskActRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _KioskActSheet(
        targetName: targetName,
        granularity: granularity,
        now: now,
        reader: reader,
        nfcEnabled: nfcEnabled,
        scanBuilder: scanBuilder,
      ),
    );

class _KioskActSheet extends StatefulWidget {
  const _KioskActSheet({
    required this.targetName,
    required this.granularity,
    required this.now,
    required this.reader,
    required this.nfcEnabled,
    required this.scanBuilder,
  });

  final String targetName;
  final BookingGranularity granularity;
  final DateTime now;
  final NfcUidReader reader;
  final bool nfcEnabled;
  final QrScanWidgetBuilder? scanBuilder;

  @override
  State<_KioskActSheet> createState() => _KioskActSheetState();
}

/// One selectable day-part option (day-based granularity).
typedef _DayOption = ({
  String key,
  String label,
  DateTime start,
  DateTime end,
});

class _KioskActSheetState extends State<_KioskActSheet> {
  KioskAction _action = KioskAction.checkIn;
  late DateTime _start;
  late DateTime _end;
  String? _dayKey;
  bool _checkInNow = true;

  bool get _dayBased => widget.granularity.isDayBased;

  int get _snap => widget.granularity.stepMinutes ?? 5;

  @override
  void initState() {
    super.initState();
    _resetWindow();
  }

  /// The default window for the CURRENT action — derived, never asked:
  /// the day part the member is standing in (day-based) or the shared
  /// walk-up window, start clamped to now.
  void _resetWindow() {
    final options = _dayBased ? _dayOptions(null) : const <_DayOption>[];
    if (options.isNotEmpty) {
      final current = options.firstWhere(
        (o) => !o.start.isAfter(widget.now) && o.end.isAfter(widget.now),
        orElse: () => options.first,
      );
      _dayKey = current.key;
      _start = current.start;
      _end = current.end;
    } else {
      final window = walkUpWindow(widget.granularity, widget.now);
      _start =
          window.start.isBefore(widget.now) ? widget.now : window.start;
      _end = window.end;
    }
  }

  /// Today's bookable day parts, already clamped to now. Passing [l10n]
  /// labels them; initState passes null (keys only).
  List<_DayOption> _dayOptions(AppLocalizations? l10n) {
    final now = widget.now;
    final morning = HalfDayWindows.morning(now);
    final afternoon = HalfDayWindows.afternoon(now);
    final fullDay = HalfDayWindows.fullDay(now);
    DateTime clamp(DateTime start) => start.isBefore(now) ? now : start;
    final options = <_DayOption>[
      if (widget.granularity != BookingGranularity.fullDay &&
          morning.end.isAfter(now))
        (
          key: 'morning',
          label: l10n?.planMorningChip ?? 'Morning',
          start: clamp(morning.start),
          end: morning.end,
        ),
      if (widget.granularity != BookingGranularity.fullDay &&
          afternoon.end.isAfter(now))
        (
          key: 'afternoon',
          label: l10n?.planAfternoonChip ?? 'Afternoon',
          start: clamp(afternoon.start),
          end: afternoon.end,
        ),
      if (fullDay.end.isAfter(now))
        (
          key: 'day',
          label: l10n?.planFullDayChip ?? 'Day',
          start: clamp(fullDay.start),
          end: fullDay.end,
        ),
    ];
    if (options.isNotEmpty) return options;
    // After the working day: the walk-up overtime rule — now → the end
    // the shared window computes.
    final overtime = walkUpWindow(widget.granularity, now);
    return [
      (
        key: 'rest',
        label: l10n?.kioskRestOfDay ?? 'Rest of the day',
        start: overtime.start,
        end: overtime.end,
      ),
    ];
  }

  Future<void> _pickTime({required bool isStart}) async {
    final base = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null || !mounted) return;
    final now = widget.now;
    // Snap DOWN to the workspace grid, then keep the window inside
    // today and after now — the kiosk books the day you are standing in.
    final minutes = (picked.hour * 60 + picked.minute) ~/ _snap * _snap;
    var at = DateTime(
        now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    setState(() {
      if (isStart) {
        if (at.isBefore(now)) at = now;
        _start = at;
        if (!_end.isAfter(_start)) {
          _end = _start.add(Duration(minutes: _snap));
        }
      } else {
        if (!at.isAfter(_start)) at = _start.add(Duration(minutes: _snap));
        _end = at;
      }
    });
  }

  /// The badge arrived — the sheet's ONE exit. Everything the screen
  /// needs to act rides along; no further confirmation follows.
  void _onBadge(String token) {
    final code = token.trim();
    if (code.isEmpty) return;
    final startedReserve = _action == KioskAction.reserve &&
        !_start.isAfter(widget.now);
    Navigator.of(context).pop((
      action: _action,
      start: _start,
      end: _end,
      checkInNow: startedReserve && _checkInNow,
      badgeToken: code,
    ));
  }

  /// The rule the derived window follows, spelled out — the settings
  /// ARE the explanation ("include the settings on which base the
  /// check-in must be done").
  String _basisLine(AppLocalizations? l10n, MaterialLocalizations time) {
    final granularityLabel = switch (widget.granularity) {
      BookingGranularity.flexible =>
        l10n?.availabilityGranularityFlexible ?? 'Free time period',
      BookingGranularity.halfDay => l10n?.availabilityGranularityHalfDay ??
          'Half days (morning & afternoon)',
      BookingGranularity.minutes5 =>
        l10n?.availabilityGranularity5 ?? '5-minute slots',
      BookingGranularity.minutes15 =>
        l10n?.availabilityGranularity15 ?? '15-minute slots',
      BookingGranularity.minutes30 =>
        l10n?.availabilityGranularity30 ?? '30-minute slots',
      BookingGranularity.minutes60 =>
        l10n?.availabilityGranularity60 ?? '1-hour slots',
      BookingGranularity.fullDay =>
        l10n?.availabilityGranularityFullDay ?? 'Full days only',
      BookingGranularity.hours =>
        l10n?.availabilityGranularityHours ?? 'Real hours',
    };
    String range(({DateTime start, DateTime end}) w) =>
        '${time.formatTimeOfDay(TimeOfDay.fromDateTime(w.start))}–'
        '${time.formatTimeOfDay(TimeOfDay.fromDateTime(w.end))}';
    final now = widget.now;
    final hours = widget.granularity == BookingGranularity.halfDay
        ? '${range(HalfDayWindows.morning(now))} / '
            '${range(HalfDayWindows.afternoon(now))}'
        : range(HalfDayWindows.fullDay(now));
    return l10n?.kioskBasis(granularityLabel, hours) ??
        '$granularityLabel · today $hours';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final timeLabel = MaterialLocalizations.of(context);
    final booksWindow = _action != KioskAction.checkOut;
    final offerCheckIn = _action == KioskAction.reserve &&
        !_start.isAfter(widget.now);

    return SingleChildScrollView(
      // One tall surface on a small kiosk screen: scrolls, never clips.
      child: SheetShell(
        title: widget.targetName,
        children: [
        // The action — Check in preselected: the walk-up's one truth.
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('kiosk-check-in'),
              avatar: const Icon(Icons.login_outlined, size: 18),
              label: Text(l10n?.kioskCheckIn ?? 'Check in'),
              selected: _action == KioskAction.checkIn,
              onSelected: (_) => setState(() {
                _action = KioskAction.checkIn;
                _resetWindow();
              }),
            ),
            ChoiceChip(
              key: const ValueKey('kiosk-reserve'),
              avatar: const Icon(Icons.event_available_outlined, size: 18),
              label: Text(l10n?.kioskReserve ?? 'Reserve'),
              selected: _action == KioskAction.reserve,
              onSelected: (_) => setState(() {
                _action = KioskAction.reserve;
                _resetWindow();
              }),
            ),
            ChoiceChip(
              key: const ValueKey('kiosk-check-out'),
              avatar: const Icon(Icons.logout_outlined, size: 18),
              label: Text(l10n?.kioskCheckOut ?? 'Check out'),
              selected: _action == KioskAction.checkOut,
              onSelected: (_) =>
                  setState(() => _action = KioskAction.checkOut),
            ),
          ],
        ),
        if (booksWindow) ...[
          const SizedBox(height: 12),
          if (_dayBased)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _dayOptions(l10n))
                  ChoiceChip(
                    key: ValueKey('kiosk-period-${option.key}'),
                    label: Text(option.label),
                    selected: _dayKey == option.key,
                    // Checking in = being there now: a part of the day
                    // that has not begun cannot be checked into.
                    onSelected: _action == KioskAction.checkIn &&
                            option.start.isAfter(widget.now)
                        ? null
                        : (_) => setState(() {
                              _dayKey = option.key;
                              _start = option.start;
                              _end = option.end;
                            }),
                  ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('kiosk-period-start'),
                    icon: const Icon(Icons.schedule_outlined),
                    // Check-in starts the moment the badge confirms.
                    onPressed: _action == KioskAction.checkIn
                        ? null
                        : () => _pickTime(isStart: true),
                    label: Text(
                      '${l10n?.planFromLabel ?? 'From'} '
                      '${timeLabel.formatTimeOfDay(TimeOfDay.fromDateTime(_start))}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('kiosk-period-end'),
                    icon: const Icon(Icons.schedule),
                    onPressed: () => _pickTime(isStart: false),
                    label: Text(
                      '${l10n?.planToLabel ?? 'To'} '
                      '${timeLabel.formatTimeOfDay(TimeOfDay.fromDateTime(_end))}',
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            bookingRangeText(l10n, _start, _end),
            key: const ValueKey('kiosk-period-range'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (offerCheckIn)
            SwitchListTile(
              key: const ValueKey('kiosk-period-checkin-now'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                  l10n?.kioskCheckInRightAway ?? 'Check in right away'),
              value: _checkInNow,
              onChanged: (value) => setState(() => _checkInNow = value),
            ),
          const SizedBox(height: 2),
          // The rule behind the numbers — settings transparency.
          Text(
            _basisLine(l10n, timeLabel),
            key: const ValueKey('kiosk-basis'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Divider(height: 24),
        // The badge completes the act DIRECTLY — no continue button, no
        // confirm dialog after.
        _BadgeCapture(
          reader: widget.reader,
          nfcEnabled: widget.nfcEnabled,
          scanBuilder: widget.scanBuilder,
          l10n: l10n,
          onCode: _onBadge,
        ),
        ],
      ),
    );
  }
}

/// The badge capture (0043 + 0046), embedded: type/scan the QR code, OR
/// tap an RFID/NFC card. When NFC is available a read session runs while
/// the sheet is open; the first tap fires [onCode] with the tag's
/// normalized UID. The code lives only here and dies with the sheet.
class _BadgeCapture extends StatefulWidget {
  const _BadgeCapture({
    required this.reader,
    required this.nfcEnabled,
    required this.scanBuilder,
    required this.l10n,
    required this.onCode,
  });

  final NfcUidReader reader;
  final bool nfcEnabled;

  /// Camera scanner embed, or null off-mobile (wedge scanners remain).
  final QrScanWidgetBuilder? scanBuilder;
  final AppLocalizations? l10n;
  final ValueChanged<String> onCode;

  @override
  State<_BadgeCapture> createState() => _BadgeCaptureState();
}

/// What the RFID path is doing, shown IN the sheet (field report: "the
/// RFID was not read" was undiagnosable at the wall — no NFC hardware,
/// NFC off in Android settings and a dead session all looked identical).
enum _NfcUiState { checking, reading, off, unsupported, failed, featureOff }

class _BadgeCaptureState extends State<_BadgeCapture> {
  final _controller = TextEditingController();
  _NfcUiState _nfc = _NfcUiState.checking;
  bool _cameraReady = false;

  /// Whether the camera scanner is mounted. Field-proven root cause: on
  /// the wall tablet the RFID tap reads fine with NO camera streaming
  /// (Samsung camera/NFC coexistence) — so when NFC is ready the sheet
  /// opens in CARD mode and the QR camera is one tap away.
  bool _cameraMode = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startReaders();
  }

  /// NFC first, camera second: the RFID reader-mode session must be
  /// registered before the camera pipeline spins up.
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
    setState(() {
      _nfc = _NfcUiState.failed;
      _cameraMode = true;
    });
  }

  void _submit(String value) {
    final code = value.trim();
    if (_done || !mounted || code.isEmpty) return;
    _done = true;
    widget.onCode(code);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n?.kioskPresentBadge ?? 'Present your badge',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
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
        if (widget.scanBuilder != null && _cameraReady && _cameraMode) ...[
          const SizedBox(height: 12),
          ScanCameraBox(
            cameraKey: const ValueKey('kiosk-badge-camera'),
            onCode: _submit,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('kiosk-badge-field'),
          controller: _controller,
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
