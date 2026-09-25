// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invite_uri.dart';

/// Join presentation; commands and pending state belong to the entry flow.
class OnboardingJoinForm extends StatelessWidget {
  const OnboardingJoinForm({super.key, required this.formKey,
    required this.code, required this.busy, required this.onJoin,
    required this.onScan});
  final GlobalKey<FormState> formKey;
  final TextEditingController code;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: code,
              decoration: InputDecoration(
                labelText: l10n?.workspaceInviteCodeLabel ?? 'Invite code',
                helperText: l10n?.workspaceInvitePasteHint ??
                    'Paste the whole invitation message — '
                        'the ID is found automatically.',
                helperMaxLines: 2,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => InviteUriCodec.extractCode(v ?? '').isEmpty
                  ? (l10n?.workspaceInviteCodeInvalid ??
                      'No workspace ID found — paste the invitation or '
                          'type the ID.')
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : onJoin,
              child: Text(l10n?.onboardingJoinButton ?? 'Join'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n?.onboardingScanButton ?? 'Scan QR code'),
            ),
          ],
        ),
      );
  }
}
