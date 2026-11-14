// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 — the paper the business's documents are printed on: the country's
// usual one unless another the country allows is chosen. The papers offered
// are the country's row's; when it allows one only, the helper says why.
import 'package:deskilo_document_model/paper.dart';
import 'package:flutter/material.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/jurisdiction/installed_payment_slips.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../l10n/app_localizations.dart';

/// The name of [paper] as the settings show it.
String _paperName(AppLocalizations l10n, Paper paper) => switch (paper) {
  Paper.a4 => l10n.workspacePaperA4,
  Paper.letter => l10n.workspacePaperLetter,
};

/// Why a business of [country] has no choice of paper, or null when it has.
String? _paperOnlyReason(AppLocalizations l10n, Country country) {
  if (country.papers.length != 1) return null;
  final only = _paperName(l10n, country.papers.single);
  return paymentSlipOf(country.code) != null
      ? l10n.workspacePaperOnlySlip(only)
      : l10n.workspacePaperOnly(only);
}

/// The paper choice of the settings form, held by [paper]: null follows
/// [countryCode].
class WorkspacePaperField extends StatelessWidget {
  const WorkspacePaperField({
    super.key,
    required this.countryCode,
    required this.paper,
    required this.enabled,
  });

  final String countryCode;
  final ValueNotifier<Paper?> paper;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final country = CountryCatalog.byCode(countryCode);
    final only = _paperOnlyReason(l10n, country);
    return ValueListenableBuilder<Paper?>(
      valueListenable: paper,
      builder: (context, chosen, _) => DropdownButtonFormField<Paper?>(
        key: const Key('workspaceSettingsPaper'),
        isExpanded: true,
        initialValue: country.papers.contains(chosen) ? chosen : null,
        decoration: InputDecoration(
          labelText: l10n.workspacePaperLabel,
          helperMaxLines: 3,
          helperText: only ?? l10n.workspacePaperHelper,
        ),
        items: [
          DropdownMenuItem(
            child: Text(
              l10n.workspacePaperFollows(
                _paperName(l10n, country.paper),
                localizedCountryName(l10n, country.code),
              ),
            ),
          ),
          if (only == null)
            for (final p in country.papers)
              DropdownMenuItem(value: p, child: Text(_paperName(l10n, p))),
        ],
        onChanged: enabled && only == null ? (p) => paper.value = p : null,
      ),
    );
  }
}
