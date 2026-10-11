// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — how often the workspace files its VAT return, asked on the
// legal identity beside the tax point, and the words the declarations
// screen uses for a period of that length.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vat_declaration_period.dart';
import '../vat_tax_point_labels.dart';

/// The period's length, as an owner reads it.
String vatDeclarationPeriodName(
  AppLocalizations? l10n,
  VatDeclarationPeriod period,
) {
  final words = vatWords(l10n);
  return switch (period) {
    VatDeclarationPeriod.month => words.vatDeclPeriodMonth,
    VatDeclarationPeriod.quarter => words.vatDeclPeriodQuarter,
    VatDeclarationPeriod.annual => words.vatDeclPeriodAnnual,
  };
}

/// One filing period: « September 2026 », « Q3 2026 », « 2026 ».
String vatFilingPeriodLabel(
  AppLocalizations? l10n,
  VatFilingPeriod period,
) {
  final start = period.start;
  final months = (period.end.year - start.year) * 12 +
      period.end.month -
      start.month +
      1;
  if (months >= 12) return '${start.year}';
  if (months == 3) return 'Q${(start.month - 1) ~/ 3 + 1} ${start.year}';
  return DateFormat.yMMMM(l10n?.localeName).format(start);
}

class VatDeclarationPeriodField extends StatelessWidget {
  const VatDeclarationPeriodField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final VatDeclarationPeriod value;
  final ValueChanged<VatDeclarationPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = vatWords(l10n);
    return DropdownButtonFormField<VatDeclarationPeriod>(
      key: const ValueKey('legal-identity-declaration-period'),
      initialValue: value,
      isExpanded: true,
      items: [
        for (final period in VatDeclarationPeriod.values)
          DropdownMenuItem(
            value: period,
            child: Text(vatDeclarationPeriodName(l10n, period)),
          ),
      ],
      onChanged: (v) => onChanged(v ?? value),
      decoration: InputDecoration(
        labelText: words.vatDeclPeriodField,
        helperMaxLines: 4,
        helperText: words.vatDeclPeriodHint,
        suffixIcon: HelpDot(
          words.helpTopicVat,
          anchor: HelpAnchor.moneyVatDeclaration,
        ),
      ),
    );
  }
}
