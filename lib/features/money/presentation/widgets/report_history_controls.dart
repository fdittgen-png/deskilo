// SPDX-License-Identifier: 0BSD
//
// Undo and redo for the report designer's app bar (#1056).
//
// Its own file because the bar has to hold two shapes of the same pair —
// two icon buttons where there is room, one overflow menu where there is
// not — and inlining both put invoice_template_sheet.dart over its length
// budget, which is the file #1061 already wants smaller, not larger.

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Below this width the pair folds into an overflow menu.
///
/// Back + undo + redo + a labelled Save leave a 393 dp phone about 115 dp
/// for a title that wants 110, and the title is what ellipsed: "Report
/// editor" became "Rep…", so the one word telling you where you are was
/// the one that went. Chosen so every phone folds and a tablet or desktop
/// window does not.
const double kNarrowAppBar = 420;

/// The designer's undo/redo pair, in whichever shape the width allows.
class ReportHistoryControls extends StatelessWidget {
  const ReportHistoryControls({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final undoLabel = l10n?.reportDesignerUndo ?? 'Undo';
    final redoLabel = l10n?.reportDesignerRedo ?? 'Redo';

    if (MediaQuery.sizeOf(context).width >= kNarrowAppBar) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          key: const ValueKey('report-designer-undo'),
          icon: const Icon(Icons.undo),
          tooltip: undoLabel,
          onPressed: canUndo ? onUndo : null,
        ),
        IconButton(
          key: const ValueKey('report-designer-redo'),
          icon: const Icon(Icons.redo),
          tooltip: redoLabel,
          onPressed: canRedo ? onRedo : null,
        ),
      ]);
    }

    // Folded away is not taken away: both stay reachable, and each still
    // shows whether it has anything to do.
    return PopupMenuButton<VoidCallback>(
      key: const ValueKey('report-designer-history-menu'),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem<VoidCallback>(
          key: const ValueKey('report-designer-undo-item'),
          enabled: canUndo,
          value: onUndo,
          child: Text(undoLabel),
        ),
        PopupMenuItem<VoidCallback>(
          key: const ValueKey('report-designer-redo-item'),
          enabled: canRedo,
          value: onRedo,
          child: Text(redoLabel),
        ),
      ],
    );
  }
}
