// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4028 — what a restored file or an applied template left out, said
// where the result is shown: one sentence per reason, built from the two
// currencies or the two countries.
import 'package:flutter/material.dart';

import '../../../../core/i18n/country_names.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/configuration_refusal.dart';

/// Where the configuration came from, which the sentences name.
enum ConfigurationOrigin { file, template }

/// One sentence per reason [refused] holds.
List<String> _configurationRefusalLines(
  AppLocalizations l10n,
  List<ConfigurationRefusal> refused,
  ConfigurationOrigin origin,
) => [
  for (final r in ConfigurationRefusal.perReason(refused))
    switch ((r.code, origin)) {
      (ConfigurationRefusalCode.currency, ConfigurationOrigin.file) =>
        l10n.configurationRefusedPricesFile(r.source, r.target),
      (ConfigurationRefusalCode.currency, ConfigurationOrigin.template) =>
        l10n.configurationRefusedPricesTemplate(r.source, r.target),
      (ConfigurationRefusalCode.country, ConfigurationOrigin.file) =>
        l10n.configurationRefusedTaxFile(
          localizedCountryName(l10n, r.source),
          localizedCountryName(l10n, r.target),
        ),
      (ConfigurationRefusalCode.country, ConfigurationOrigin.template) =>
        l10n.configurationRefusedTaxTemplate(
          localizedCountryName(l10n, r.source),
          localizedCountryName(l10n, r.target),
        ),
    },
];

/// Says what [refused] left out and waits for the person to read it;
/// nothing when nothing was left out.
Future<void> showConfigurationRefusals(
  BuildContext context,
  List<ConfigurationRefusal> refused,
  ConfigurationOrigin origin,
) async {
  if (refused.isEmpty) return;
  final l10n = context.l10n;
  final lines = _configurationRefusalLines(l10n, refused, origin);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('configurationRefusals'),
      scrollable: true,
      title: Text(l10n.configurationRefusedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(line),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('configurationRefusalsOk'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
        ),
      ],
    ),
  );
}
