// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/scan/scan_camera_box.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/act_trace.dart';
import '../../../../core/ui/app_snack.dart';
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
    // #1652 — the WHOLE payload goes back to the join field, so a v2
    // invitation keeps the server it names; the field shows it and the
    // person reviews it before anything is joined.
    final read = InvitationReader.read(payload);
    final usable = read.problem != InvitationProblem.noCode;
    ActTrace.scan.step('join-qr decoded', {
      'shape': ActTrace.payloadShape(payload),
      'usable': usable,
    });
    if (!usable) {
      ActTrace.scan.refused('join-qr', {
        'shape': ActTrace.payloadShape(payload),
        'reason': 'not-an-invite',
      });
      final l10n = context.l10n;
      AppSnack.info(
        context,
        l10n.scanJoinNotAnInvite,
        replace: true,
      );
      return;
    }
    _done = true;
    Navigator.of(context).pop(payload.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanJoinTitle),
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
            l10n.scanJoinHelp,
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
