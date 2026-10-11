// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WizardText(
            l10n.instanceOwnerClaimIntro,
          ),
          TextField(
            key: const ValueKey('instance-owner-email'),
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.instanceOwnerClaimLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
