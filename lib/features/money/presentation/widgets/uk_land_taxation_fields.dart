// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/invoice_legal.dart';

/// #2359 — the United Kingdom treats land as exempt unless the owner opted
/// to tax the building (VAT Notice 742). The choice is a workspace setting:
/// the option (with its date and HMRC's notification reference) and the
/// serviced package of facilities, which is standard-rated either way.
/// Owns its controllers; the screen hands it the stored identity and takes
/// the edited one back when it saves.
class UkLandTaxationForm extends ChangeNotifier {
  final date = TextEditingController();
  final reference = TextEditingController();
  bool optionToTax = false;
  bool facilitiesPackage = false;
  // #2360 — Switzerland: rooms only (exempt, art. 21) instead of a package.
  bool bareLetting = false;
  // #2361 — Canada: the quick method of accounting for GST/HST.
  bool quickMethod = false;

  void load(InvoiceLegal legal) {
    optionToTax = legal.optionToTax;
    facilitiesPackage = legal.facilitiesPackage;
    bareLetting = legal.lettingKind == 'bare';
    quickMethod = legal.quickMethod;
    date.text = legal.optionToTaxDate;
    reference.text = legal.optionToTaxReference;
  }

  InvoiceLegal applyTo(InvoiceLegal legal) => legal.withLandTaxation(
    optionToTax: optionToTax,
    optionToTaxDate: date.text,
    optionToTaxReference: reference.text,
    facilitiesPackage: facilitiesPackage,
    lettingKind: bareLetting ? 'bare' : '',
    quickMethod: quickMethod,
  );

  void choose({bool? option, bool? package, bool? bare, bool? quick}) {
    optionToTax = option ?? optionToTax;
    facilitiesPackage = package ?? facilitiesPackage;
    bareLetting = bare ?? bareLetting;
    quickMethod = quick ?? quickMethod;
    notifyListeners();
  }

  @override
  void dispose() {
    date.dispose();
    reference.dispose();
    super.dispose();
  }
}

class UkLandTaxationFields extends StatelessWidget {
  const UkLandTaxationFields({super.key, required this.form});

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
          Text(l10n.ukLandTaxTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.ukLandTaxHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SwitchListTile(
            key: const ValueKey('legal-identity-option-to-tax'),
            contentPadding: EdgeInsets.zero,
            value: form.optionToTax,
            title: Text(l10n.ukOptionToTax),
            onChanged: (v) => form.choose(option: v),
          ),
          if (form.optionToTax) ...[
            AppTextField(
              key: const ValueKey('legal-identity-option-date'),
              controller: form.date,
              label: l10n.ukOptionToTaxDate,
              keyboardType: TextInputType.datetime,
            ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('legal-identity-option-reference'),
              controller: form.reference,
              label: l10n.ukOptionToTaxReference,
            ),
          ],
          SwitchListTile(
            key: const ValueKey('legal-identity-facilities-package'),
            contentPadding: EdgeInsets.zero,
            value: form.facilitiesPackage,
            title: Text(l10n.ukFacilitiesPackage),
            subtitle: Text(l10n.ukFacilitiesPackageHelp),
            onChanged: (v) => form.choose(package: v),
          ),
        ],
      ),
    );
  }
}
