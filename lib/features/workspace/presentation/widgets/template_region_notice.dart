// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_template.dart';

/// #1656 — the chosen template was made somewhere else. Its region is
/// offered, never applied on its own: what the person typed stays until
/// they choose the template's values. Shown only when they differ.
class TemplateRegionNotice extends StatelessWidget {
  const TemplateRegionNotice({
    super.key,
    required this.suggestion,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    required this.onUse,
    this.enabled = true,
  });

  final RegionalSuggestion suggestion;
  final String countryCode;
  final String currencyCode;
  final String timezone;
  final VoidCallback onUse;
  final bool enabled;

  /// A country the catalogue does not know is not offered.
  static bool offerable(RegionalSuggestion s) =>
      s.countryCode == null ||
      CountryCatalog.countries.any((c) => c.code == s.countryCode);

  @override
  Widget build(BuildContext context) {
    if (!offerable(suggestion) ||
        !suggestion.differsFrom(
          countryCode: countryCode,
          currencyCode: currencyCode,
          timezone: timezone,
        )) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final values = [
      ?suggestion.countryCode,
      ?suggestion.currencyCode,
      ?suggestion.timezone,
    ].join(' · ');
    return Column(
      key: const ValueKey('template-region-notice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineBanner(
          icon: Icons.public,
          text:
              l10n?.templateRegionSuggested(values) ??
              'This template was made for $values. Your choice is kept unless you use its values.',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('template-region-use'),
            onPressed: enabled ? onUse : null,
            child: Text(
              l10n?.templateRegionUse ?? 'Use the template\'s region',
            ),
          ),
        ),
      ],
    );
  }
}
