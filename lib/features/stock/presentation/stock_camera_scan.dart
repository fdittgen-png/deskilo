// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the phone's camera as a scanner for a goods sheet: it reads product barcodes (EAN, UPC, Code 128)
// and the 2D labels of places and GS1 products, and every code goes through the SAME path a typed scan takes (the
// sheet's scan feed: "scan the place, then the items"), so the rights, the resolution and the request id are the
// sheet's own. It stays open for repeated scans, says how many codes it read and what the last one was, and
// confirms each read as the device prefers (nothing, a vibration, a click). A GTIN whose check digit is wrong is a
// misread: it is said and never sent. The same code seen again within a moment is the same read.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/scan/goods_camera_box.dart';
import '../../../core/scan/gs1.dart';
import '../../../core/scan/qr_scan_widget.dart';
import '../../../core/scan/scan_no_camera.dart';
import '../../../core/scan/scan_prefs.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/clock.dart';
import '../domain/stock_scan_session.dart';
import 'stock_scan_feed.dart';

/// Whether this device can host the camera scanner (a phone or a tablet; a desktop and the browser say so).
bool get _cameraSupported => qrScanSupported;

/// Opens the camera scanner over [feed]; the dialog stays until it is closed.
Future<void> showStockCameraScan(BuildContext context, StockScanFeed feed) =>
    showDialog<void>(context: context, builder: (_) => _CameraDialog(feed: feed));

class _CameraDialog extends ConsumerStatefulWidget {
  const _CameraDialog({required this.feed});

  final StockScanFeed feed;

  @override
  ConsumerState<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends ConsumerState<_CameraDialog> {
  /// [misread]: the last scanned text whose check digit failed; said only if the resolver finds nothing for it.
  final ValueNotifier<({int reads, String? misread})> _state = ValueNotifier((reads: 0, misread: null));
  String? _lastCode;
  DateTime? _lastAt;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final how = ref.read(scanPrefsProvider).value?.confirm ?? ScanConfirm.vibrate; // empty-ok: the default confirmation until the device's own is read
    switch (how) {
      case ScanConfirm.vibrate:
        await HapticFeedback.mediumImpact();
      case ScanConfirm.click:
        await SystemSound.play(SystemSoundType.click);
      case ScanConfirm.none:
        break;
    }
  }

  void _onCode(String text) {
    final now = ref.read(clockProvider).now();
    // the camera sees the same label in many frames: the same text within a moment is one read
    if (text == _lastCode && _lastAt != null && now.difference(_lastAt!) < const Duration(milliseconds: 1500)) return;
    _lastCode = text;
    _lastAt = now;
    final read = classifyGoodsCode(text);
    final gs1 = read.gs1;
    // a GS1 element string is resolved by its GTIN (an EAN-13 is a GTIN-14 with a leading zero), its lot and expiry kept
    if (gs1 != null) {
      final gtin = gs1.gtin.startsWith('0') ? gs1.gtin.substring(1) : gs1.gtin;
      widget.feed.scan(gtin, gs1: (lot: gs1.lot, expiresOn: gs1.expiry));
    } else {
      widget.feed.scan(text.trim());
    }
    // a failed check digit is still resolved as typed (it may be the business's own code)
    _state.value = (reads: _state.value.reads + 1, misread: read.kind == GoodsCodeKind.misread ? text.trim() : null);
    unawaited(_confirm());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('stock-camera-dialog'),
      title: Text(l10n.stockCameraTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_cameraSupported)
              GoodsCameraBox(onCode: _onCode)
            else
              Text(scanNoCameraSentence(l10n), key: const ValueKey('stock-camera-unavailable')),
            const SizedBox(height: AppSpacing.sm),
            ListenableBuilder(
              listenable: Listenable.merge([_state, widget.feed]),
              builder: (context, _) {
                final last = widget.feed.last;
                final line = last != null && last.outcome == ScanOutcome.line ? last.line : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.stockCameraCount(_state.value.reads), key: const ValueKey('stock-camera-count')),
                    if (line != null) Text(l10n.stockScanLast(line.itemName, line.shownQuantity, line.unit), key: const ValueKey('stock-camera-last')),
                    if (last != null && last.outcome == ScanOutcome.unknown && last.code == _state.value.misread)
                      Text(l10n.stockCameraMisread, key: const ValueKey('stock-camera-misread'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const ValueKey('stock-camera-close'), onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).closeButtonLabel)),
      ],
    );
  }
}
