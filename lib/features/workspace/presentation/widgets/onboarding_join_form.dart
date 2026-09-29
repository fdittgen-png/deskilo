// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invite_uri.dart';

/// Join presentation; commands and pending state belong to the entry flow.
class OnboardingJoinForm extends StatelessWidget {
  const OnboardingJoinForm({super.key, required this.formKey,
    required this.code, required this.busy, required this.onJoin,
    required this.onScan, this.onPaste});
  final GlobalKey<FormState> formKey;
  final TextEditingController code;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onScan;

  /// #1652 — reads the clipboard only when the person taps it.
  final VoidCallback? onPaste;

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
              key: const ValueKey('invitation-input'),
              validator: (v) => InvitationReader.read(v ?? '').problem ==
                      InvitationProblem.noCode
                  ? (l10n?.workspaceInviteCodeInvalid ??
                      'No workspace ID found — paste the invitation or '
                          'type the ID.')
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('invitation-review-button'),
              onPressed: busy ? null : onJoin,
              child: Text(l10n?.invitationReviewButton ?? 'Review invitation'),
            ),
            const SizedBox(height: 8),
            // Alternatives, not steps: either fills the same field.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onPaste != null)
                  OutlinedButton.icon(
                    key: const ValueKey('invitation-paste'),
                    onPressed: busy ? null : onPaste,
                    icon: const Icon(Icons.content_paste),
                    label: Text(l10n?.invitationPasteButton ?? 'Paste'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('invitation-scan'),
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n?.onboardingScanButton ?? 'Scan QR code'),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
