// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/presentation/widgets/space_act_form.dart';
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
///
/// #622: the action + derived-period core lives in the shared
/// [SpaceActForm] — the app's scan flow shows the SAME form without
/// the badge, acting as the signed-in member.
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

class _KioskActSheetState extends State<_KioskActSheet> {
  /// The shared form holds the action + window state; the badge reads
  /// it at completion time.
  final _form = GlobalKey<SpaceActFormState>();

  /// The badge arrived — the sheet's ONE exit. Everything the screen
  /// needs to act rides along; no further confirmation follows.
  void _onBadge(String token) {
    final code = token.trim();
    if (code.isEmpty) return;
    final choice = _form.currentState?.choice;
    if (choice == null) return;
    Navigator.of(context).pop((
      action: switch (choice.action) {
        SpaceAction.checkIn => KioskAction.checkIn,
        SpaceAction.reserve => KioskAction.reserve,
        SpaceAction.checkOut => KioskAction.checkOut,
      },
      start: choice.start,
      end: choice.end,
      checkInNow: choice.checkInNow,
      badgeToken: code,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      // One tall surface on a small kiosk screen: scrolls, never clips.
      child: SheetShell(
        title: widget.targetName,
        children: [
          // The shared action + derived-period core (#529/#622), with
          // the kiosk's historical widget keys.
          SpaceActForm(
            key: _form,
            keyPrefix: 'kiosk',
            granularity: widget.granularity,
            now: widget.now,
          ),
          const Divider(height: 24),
          // The badge completes the act DIRECTLY — no continue button,
          // no confirm dialog after.
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
