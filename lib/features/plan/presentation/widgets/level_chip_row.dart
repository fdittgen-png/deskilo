// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/level.dart';

/// The one horizontal level-chip selector (#187/#221 idiom), formerly
/// copy-pasted across the day timeline, the week grid and the Reserve hub's
/// plan view: a 48dp row of [ChoiceChip]s, one per level, optionally led by
/// an "All levels" sentinel chip.
///
/// Selection is the CALLER's throwaway browsing state — never the plan
/// tab's persisted default (#159). With fewer than two levels the row
/// renders nothing (a single level needs no picker).
class LevelChipRow extends StatelessWidget {
  const LevelChipRow({
    super.key,
    required this.levels,
    required this.selectedLevelId,
    required this.onSelected,
    this.allLevelsLabel,
    this.allLevelsSelected = false,
    this.onAllLevelsSelected,
  });

  final List<Level> levels;

  /// Id of the selected level chip; ignored while [allLevelsSelected].
  final String? selectedLevelId;

  final ValueChanged<String> onSelected;

  /// When non-null, an "All levels" sentinel chip leads the row (#221).
  final String? allLevelsLabel;
  final bool allLevelsSelected;
  final VoidCallback? onAllLevelsSelected;

  @override
  Widget build(BuildContext context) {
    if (levels.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: kMinInteractiveDimension,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.mdH,
        children: [
          if (allLevelsLabel != null)
            Padding(
              padding: AppSpacing.xsH,
              child: ChoiceChip(
                label: Text(allLevelsLabel!),
                selected: allLevelsSelected,
                // 48dp Material tap minimum (#211).
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => onAllLevelsSelected?.call(),
              ),
            ),
          for (final Level l in levels)
            Padding(
              padding: AppSpacing.xsH,
              child: ChoiceChip(
                label: Text(l.name),
                selected: !allLevelsSelected && l.id == selectedLevelId,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => onSelected(l.id),
              ),
            ),
        ],
      ),
    );
  }
}
