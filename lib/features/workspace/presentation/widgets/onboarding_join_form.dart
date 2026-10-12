// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
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
    final l10n = context.l10n;
    return Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: code,
              decoration: InputDecoration(
                labelText: l10n.workspaceInviteCodeLabel,
                helperText: l10n.workspaceInvitePasteHint,
                helperMaxLines: 2,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.characters,
              key: const ValueKey('invitation-input'),
              validator: (v) => InvitationReader.read(v ?? '').problem ==
                      InvitationProblem.noCode
                  ? (l10n.workspaceInviteCodeInvalid)
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('invitation-review-button'),
              onPressed: busy ? null : onJoin,
              child: Text(l10n.invitationReviewButton),
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
                    label: Text(l10n.invitationPasteButton),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('invitation-scan'),
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.onboardingScanButton),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
