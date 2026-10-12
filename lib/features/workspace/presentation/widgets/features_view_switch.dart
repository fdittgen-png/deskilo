// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// The Features screen's two views (#1327): the process overview an
/// owner starts from, and every switch — the capability list with its
/// *Changed* chip (#1190) that support uses to flip one flag and see
/// what a space moved.
class FeaturesViewSwitch extends StatelessWidget {
  const FeaturesViewSwitch({
    super.key,
    required this.switches,
    required this.onChanged,
  });

  /// True while the switches view is shown.
  final bool switches;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget label(String key, String text) => Text(
      text,
      key: ValueKey('features-view-$key'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.account_tree_outlined),
            label: label(
              'processes',
              l10n.featuresViewProcesses,
            ),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.tune),
            label: label('switches', l10n.featuresViewSwitches),
          ),
        ],
        selected: {switches},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
