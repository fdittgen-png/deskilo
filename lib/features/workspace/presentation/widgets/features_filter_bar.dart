// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'feature_maturity_badge.dart';

/// The Features screen's filter line (#1190).
///
/// The screen lists 102 switches at roughly 230 px each — about eight
/// per screen, so thirteen screens of scrolling. An owner looking for
/// "the VAT one" scrolled and hoped.
///
/// Two controls, because the owner asks two questions: *where is the
/// one called X*, and *what has this space actually changed*. The
/// second is the more useful of the two and the harder to answer by
/// eye, since a switch at its default looks exactly like one that was
/// deliberately set there.
class FeaturesFilterBar extends StatelessWidget {
  const FeaturesFilterBar({
    super.key,
    required this.controller,
    required this.onQuery,
    required this.changedOnly,
    required this.onChangedOnly,
    required this.changedCount,
    this.maturity = FeatureMaturityFilter.all,
    this.onMaturity,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQuery;

  /// Show only the features this workspace has moved off their default.
  final bool changedOnly;
  final ValueChanged<bool> onChangedOnly;

  /// How many there are, so the chip says whether it is worth tapping.
  final int changedCount;

  /// #1850 — the maturity/lifecycle filter; hidden without a callback.
  final FeatureMaturityFilter maturity;
  final ValueChanged<FeatureMaturityFilter>? onMaturity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final changedLabel = l10n?.featuresFilterChanged ?? 'Changed';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('features-search'),
              controller: controller,
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                labelText: l10n?.featuresSearchLabel ?? 'Search features',
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('features-search-clear'),
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onQuery('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            key: const ValueKey('features-filter-changed'),
            label: Text(
              changedCount == 0
                  ? changedLabel
                  : '$changedLabel · $changedCount',
            ),
            selected: changedOnly,
            onSelected: onChangedOnly,
          ),
          if (onMaturity != null) ...[
            const SizedBox(width: AppSpacing.sm),
            FeatureMaturityFilterButton(
                value: maturity, onChanged: onMaturity!),
          ],
        ],
      ),
    );
  }
}
