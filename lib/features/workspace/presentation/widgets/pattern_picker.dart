// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the owner picks how the space's colour is drawn where it is
// told apart from the others: one tile per curated pattern, each a
// preview in the space's own colour.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../domain/workspace_branding.dart';
import 'brand_swatch.dart';

/// The name of [pattern] in the reader's language.
String brandPatternLabel(AppLocalizations? l10n, BrandPattern pattern) {
  final t = l10n ?? AppLocalizationsEn();
  return switch (pattern) {
    BrandPattern.solid => t.coloursPatternSolid,
    BrandPattern.stripes => t.coloursPatternStripes,
    BrandPattern.dots => t.coloursPatternDots,
    BrandPattern.grid => t.coloursPatternGrid,
    BrandPattern.waves => t.coloursPatternWaves,
  };
}

class PatternPicker extends StatelessWidget {
  const PatternPicker({
    required this.color,
    required this.selected,
    required this.onPick,
    this.busy = false,
    super.key,
  });

  /// The space's colour the previews are drawn in.
  final Color color;
  final BrandPattern? selected;
  final ValueChanged<BrandPattern> onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = l10n ?? AppLocalizationsEn();
    final scheme = Theme.of(context).colorScheme;
    final current = selected ?? BrandPattern.solid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.coloursPatternTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          t.coloursPatternHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final pattern in BrandPattern.values)
              Semantics(
                button: true,
                selected: pattern == current,
                label: brandPatternLabel(l10n, pattern),
                child: InkWell(
                  key: ValueKey('colours-pattern-${pattern.name}'),
                  onTap: busy ? null : () => onPick(pattern),
                  borderRadius: AppRadius.mdAll,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(
                            color: pattern == current
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: pattern == current ? 3 : 1,
                          ),
                        ),
                        child: BrandSwatch(
                          color: color,
                          pattern: pattern,
                          borderRadius: AppRadius.mdAll,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ExcludeSemantics(
                        child: Text(
                          brandPatternLabel(l10n, pattern),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
