// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
              l10n?.featuresViewProcesses ?? 'Processes',
            ),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.tune),
            label: label('switches', l10n?.featuresViewSwitches ?? 'Switches'),
          ),
        ],
        selected: {switches},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
