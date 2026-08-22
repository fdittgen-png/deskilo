// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invite_uri.dart';

/// Camera scanner for workspace QR codes (#88, rebuilt for #572). Runs on
/// the SHARED scan embed (ScanCameraBox): the injectable seam widget tests
/// drive, the tuned full-frame decoder (#564 — the default centred 50%
/// crop never read a code held slightly off-centre), and the on-the-spot
/// lens flip a handheld joiner needs (the device default favours kiosks'
/// front camera). Pops with the scanned code; the caller joins and the
/// router auto-connects.
class ScanJoinScreen extends ConsumerStatefulWidget {
  const ScanJoinScreen({super.key});

  @override
  ConsumerState<ScanJoinScreen> createState() => _ScanJoinScreenState();
}

class _ScanJoinScreenState extends ConsumerState<ScanJoinScreen> {
  bool _done = false;

  void _onCode(String payload) {
    if (_done) return;
    // Role-scoped invite URLs and legacy raw-code QRs both resolve to
    // their code; unrelated QRs resolve to '' and are ignored.
    final code = InviteUriCodec.decodeCode(payload);
    if (code.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.scanJoinTitle ?? 'Scan workspace QR'),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          ScanCameraBox(
            cameraKey: const ValueKey('scan-join-camera'),
            onCode: _onCode,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n?.scanJoinHelp ??
                'Point the camera at the invitation QR — the code is '
                    'taken over and joined automatically.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
