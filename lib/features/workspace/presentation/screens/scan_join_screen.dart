// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../../../l10n/app_localizations.dart';

/// Camera scanner for workspace QR codes (#88). flutter_zxing keeps this
/// libre / GMS-free (ADR 0003 — same choice as Sparkilo). Pops with the
/// scanned code; the caller joins and the router auto-connects.
class ScanJoinScreen extends StatefulWidget {
  const ScanJoinScreen({super.key});

  @override
  State<ScanJoinScreen> createState() => _ScanJoinScreenState();
}

class _ScanJoinScreenState extends State<ScanJoinScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.scanJoinTitle ?? 'Scan workspace QR'),
      ),
      body: ReaderWidget(
        showFlashlight: false,
        showGallery: false,
        onScan: (result) {
          if (_done) return;
          final code = result.text;
          if (code == null || code.trim().isEmpty) return;
          _done = true;
          Navigator.of(context).pop(code.trim().toUpperCase());
        },
      ),
    );
  }
}
