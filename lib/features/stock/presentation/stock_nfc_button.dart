// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the phone's NFC beside a scanner: one tap on the button reads ONE tag (the app's own
// `NfcUidReader`, the one badges and seats bind with -- no second NFC stack), and its UID goes where a scanned
// code goes. The button is there only where the business uses tags (`stockTags`) and the device reads NFC; on a
// device without NFC it is absent and the guide says why. A UHF (EPC) tag cannot be read by a phone: that is said
// in words where an item uses them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/nfc/nfc_uid_reader.dart';
import '../../../core/ui/app_snack.dart';
import '../providers/stock_providers.dart';

class StockNfcButton extends ConsumerStatefulWidget {
  const StockNfcButton({required this.onUid, super.key});

  /// The tag's UID, lower-case hex as the reader gives it.
  final ValueChanged<String> onUid;

  @override
  ConsumerState<StockNfcButton> createState() => _StockNfcButtonState();
}

class _StockNfcButtonState extends ConsumerState<StockNfcButton> {
  late final NfcUidReader _reader = ref.read(nfcUidReaderProvider);
  late final Future<bool> _available = _reader.isAvailable();
  bool _reading = false;

  @override
  void dispose() {
    // a session left open would keep the phone polling after the sheet is gone
    if (_reading) unawaited(_reader.stop());
    super.dispose();
  }

  Future<void> _read() async {
    final reader = _reader;
    setState(() => _reading = true);
    final started = await reader.startRead(
      onUid: (uid) {
        unawaited(reader.stop());
        if (!mounted) return;
        setState(() => _reading = false);
        widget.onUid(uid);
      },
    );
    if (!started && mounted) {
      setState(() => _reading = false);
      AppSnack.error(context, context.l10n.stockScanNfcFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(stockTagsProvider)) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final l10n = context.l10n;
        return Row(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('stock-scan-nfc'),
              icon: const Icon(Icons.nfc),
              label: Text(l10n.stockScanNfc),
              onPressed: _reading ? null : _read,
            ),
            if (_reading) ...[
              const SizedBox(width: 12),
              Flexible(child: Text(l10n.stockScanNfcReading, key: const ValueKey('stock-scan-nfc-reading'))),
            ],
          ],
        );
      },
    );
  }
}
