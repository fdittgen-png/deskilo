// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/act_trace.dart';
import '../../../../core/ui/app_snack.dart';
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
    // their code. #791 — anything else used to `return` here, which is
    // why "the app could not recognise the barcode" was reported for a
    // scanner that was decoding perfectly well: a decoded-but-unusable QR
    // and a QR that never decoded at all looked identical from the
    // outside, and neither left a trace.
    //
    // The decode is now recorded by SHAPE (never the code itself — an
    // invite code is a secret and traces get exported), and a QR we
    // cannot use says so instead of being swallowed.
    final code = InviteUriCodec.extractCode(payload);
    ActTrace.scan.step('join-qr decoded', {
      'shape': ActTrace.payloadShape(payload),
      'usable': code.isNotEmpty,
    });
    if (code.isEmpty) {
      ActTrace.scan.refused('join-qr', {
        'shape': ActTrace.payloadShape(payload),
        'reason': 'not-an-invite',
      });
      final l10n = AppLocalizations.of(context);
      AppSnack.info(
        context,
        l10n?.scanJoinNotAnInvite ??
            'That QR is not a DesKilo invitation — scan the one from the '
                'invitation message.',
        replace: true,
      );
      return;
    }
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
            // A joiner holds their phone up to the invite — back lens.
            defaultFront: false,
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
