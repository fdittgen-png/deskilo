// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'instance_done_step.dart';

/// #1829 — the new instance's owner: the e-mail the creator will sign up
/// with. The wizard records it as a pending claim; the account that
/// confirms that address and claims from Settings → Instance owner becomes the
/// owner. Nothing is granted by typing it.
class InstanceOwnerClaimField extends StatelessWidget {
  const InstanceOwnerClaimField({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WizardText(
            l10n?.instanceOwnerClaimIntro ??
                'Who owns this instance? Enter the e-mail you will sign up '
                    'with on it. After you confirm that address, claim the '
                    'ownership from Settings → Instance owner.',
          ),
          TextField(
            key: const ValueKey('instance-owner-email'),
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n?.instanceOwnerClaimLabel ?? 'Owner e-mail',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
