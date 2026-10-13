// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import 'uk_land_taxation_fields.dart';

/// #2361 — what a Canadian registrant adds to the legal identity: the QST
/// registration number (kept in the legal id, printed beside the GST/HST
/// number when the QST is charged) and the quick method of accounting.
/// The GST/HST business number itself is the VAT id of the screen.
class CanadaTaxFields extends StatelessWidget {
  const CanadaTaxFields({
    super.key,
    required this.form,
    required this.qstNumber,
  });

  final UkLandTaxationForm form;
  final TextEditingController qstNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.caTaxTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.caTaxHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            key: const ValueKey('legal-identity-qst-number'),
            controller: qstNumber,
            label: l10n.caQstNumber,
            helper: l10n.caQstNumberHelp,
          ),
          SwitchListTile(
            key: const ValueKey('legal-identity-quick-method'),
            contentPadding: EdgeInsets.zero,
            value: form.quickMethod,
            title: Text(l10n.caQuickMethod),
            subtitle: Text(l10n.caQuickMethodHelp),
            onChanged: (v) => form.choose(quick: v),
          ),
        ],
      ),
    );
  }
}
