// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import 'uk_land_taxation_fields.dart';

/// #2360 — the letting of premises in Switzerland: a package of services
/// is taxed at the normal rate; rooms only are exempt (art. 21 Abs. 2
/// Ziff. 21 MWSTG) unless the owner opted (art. 22). Edits the same form
/// the United Kingdom's fields do.
class SwissLettingFields extends StatelessWidget {
  const SwissLettingFields({super.key, required this.form});

  final UkLandTaxationForm form;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chLettingTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.chLettingHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SwitchListTile(
            key: const ValueKey('legal-identity-bare-letting'),
            contentPadding: EdgeInsets.zero,
            value: form.bareLetting,
            title: Text(l10n.chBareLetting),
            subtitle: Text(l10n.chBareLettingHelp),
            onChanged: (v) => form.choose(bare: v),
          ),
          if (form.bareLetting) ...[
            SwitchListTile(
              key: const ValueKey('legal-identity-option-to-tax'),
              contentPadding: EdgeInsets.zero,
              value: form.optionToTax,
              title: Text(l10n.chOptionToTax),
              onChanged: (v) => form.choose(option: v),
            ),
            if (form.optionToTax)
              AppTextField(
                key: const ValueKey('legal-identity-option-date'),
                controller: form.date,
                label: l10n.chOptionToTaxDate,
                keyboardType: TextInputType.datetime,
              ),
          ],
        ],
      ),
    );
  }
}
