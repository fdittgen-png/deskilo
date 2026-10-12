// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../screens/editor_tool.dart';

/// The armed tool, said out loud on the canvas (#1216).
///
/// Arming a tool changed what a drag did, and nothing on the canvas
/// said so: the only signal was a segment in a row that did not fit, so
/// the mode was frequently invisible. This pill says what the next
/// gesture will do and carries the way out, which is the other half of
/// the problem — a mode you cannot see is one you cannot leave either.
class EditorToolHint extends StatelessWidget {
  const EditorToolHint({
    super.key,
    required this.tool,
    required this.onCancel,
  });

  final EditorTool tool;
  final VoidCallback onCancel;

  /// What the next gesture does. Phrased as the instruction it is —
  /// "drag to draw", "tap a desk" — because the question the reader has
  /// is what to do with their finger, not what mode they are in.
  static String instruction(AppLocalizations l10n, EditorTool tool) =>
      switch (tool) {
        EditorTool.office =>
          l10n.editorHintOffice,
        EditorTool.desk => l10n.editorHintDesk,
        EditorTool.seat => l10n.editorHintSeat,
        EditorTool.image =>
          l10n.editorHintImage,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: AppSpacing.smAll,
      child: Material(
        key: const ValueKey('editor-tool-hint'),
        color: scheme.inverseSurface,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  instruction(l10n, tool),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onInverseSurface,
                      ),
                ),
              ),
              TextButton(
                key: const ValueKey('editor-tool-hint-done'),
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.inversePrimary,
                ),
                child: Text(l10n.commonDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
