// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/scan/qr_scan_widget.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/space_code.dart';

class SpaceScanSheet extends StatefulWidget {
  const SpaceScanSheet({
    super.key,
    required this.workspaceId,
    required this.scanBuilder,
    required this.l10n,
    this.nfc,
    this.seatIdForUid,
    this.explainNoCamera = false,
  });

  final String workspaceId;
  final QrScanWidgetBuilder? scanBuilder;

  /// #814 — the browser build has no camera scanner; the sheet says so
  /// instead of silently showing a typed field alone.
  final bool explainNoCamera;
  final AppLocalizations l10n;

  /// #585 — when the device can read NFC, a chair-tag tap resolves to
  /// its seat exactly like scanning the seat's QR card. Null hides the
  /// tap path (non-Android, NFC off).
  final NfcUidReader? nfc;
  final Future<String?> Function(String uid)? seatIdForUid;

  @override
  State<SpaceScanSheet> createState() => _SpaceScanSheetState();
}

class _SpaceScanSheetState extends State<SpaceScanSheet> {
  final _controller = TextEditingController();
  bool _invalid = false;
  bool _unknownTag = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final nfc = widget.nfc;
    if (nfc != null) {
      unawaited(nfc.startRead(onUid: _onTag));
    }
  }

  Future<void> _onTag(String uid) async {
    if (_done || !mounted) return;
    final seatId = await widget.seatIdForUid?.call(uid);
    if (_done || !mounted) return;
    if (seatId == null) {
      setState(() {
        _unknownTag = true;
        _invalid = false;
      });
      return;
    }
    _done = true;
    Navigator.of(context).pop((
      workspaceId: widget.workspaceId,
      kind: SpaceKind.seat,
      id: seatId,
    ));
  }

  void _submit(String raw) {
    if (_done || !mounted || raw.trim().isEmpty) return;
    final code = SpaceCodeCodec.decode(raw);
    if (code == null || code.workspaceId != widget.workspaceId) {
      setState(() {
        _invalid = true;
        _unknownTag = false;
      });
      return;
    }
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    unawaited(widget.nfc?.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SheetShell(
      title: l10n.spaceScanTitle,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.spaceScanHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (widget.nfc != null) ...[
          const SizedBox(height: 4),
          Row(
            key: const ValueKey('space-scan-nfc-hint'),
            children: [
              const Icon(Icons.nfc, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.spaceScanNfcHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (_unknownTag)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.spaceScanUnknownTag,
              key: const ValueKey('space-scan-unknown-tag'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (widget.scanBuilder == null && widget.explainNoCamera)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.scanCameraWebUnavailable,
              key: const ValueKey('space-scan-no-camera'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (widget.scanBuilder != null) ...[
          const SizedBox(height: 12),
          // Shared camera box with the lens FLIP button (field request).
          ScanCameraBox(
            cameraKey: const ValueKey('space-scan-camera'),
            onCode: _submit,
            // A member scans the printed card in hand — back lens (#773).
            defaultFront: false,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('space-scan-field'),
          controller: _controller,
          autofocus: widget.scanBuilder == null,
          decoration: InputDecoration(
            labelText: l10n.spaceScanField,
            errorText: _invalid
                ? (l10n.spaceScanInvalid)
                : null,
          ),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('space-scan-submit'),
          onPressed: () => _submit(_controller.text),
          child: Text(l10n.kioskBadgeConfirm),
        ),
      ],
    );
  }
}

/// The scanned space's actions, filtered to what THIS member may do —
/// walk-up semantics: today's window (canonical day under day-based
/// granularity, now→+4h otherwise), reserve or check in on the spot.
