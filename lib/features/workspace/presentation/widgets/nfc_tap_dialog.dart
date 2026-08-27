// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../l10n/app_localizations.dart';

/// always stopped, whether the user taps a card or cancels.
class NfcTapDialog extends StatefulWidget {
  const NfcTapDialog({super.key, required this.reader, required this.l10n});

  final NfcUidReader reader;
  final AppLocalizations? l10n;

  @override
  State<NfcTapDialog> createState() => _NfcTapDialogState();
}

class _NfcTapDialogState extends State<NfcTapDialog> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.reader.startRead(
        onUid: (uid) {
          if (_done || !mounted) return;
          _done = true;
          Navigator.of(context).pop(uid);
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(widget.reader.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n?.badgeTapCardTitle ?? 'Register a card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Icon(Icons.contactless_outlined, size: 56),
          ),
          Text(
            l10n?.badgeTapCardHint ??
                'Hold the RFID/NFC card to the back of the device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('nfc-tap-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}
