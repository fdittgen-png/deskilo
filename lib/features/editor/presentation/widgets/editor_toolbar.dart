// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../screens/editor_tool.dart';

/// The level canvas's bottom bar (#1216).
///
/// ## Why there is no Select button
///
/// There used to be six segments — Select, Office, Desk, Seat, Image,
/// Erase — and on a 360 dp phone four of them fitted. The two that fell
/// off the end were Select, the tool the editor rests in, and Office,
/// the one a new floor needs first.
///
/// Select is not a tool; it is what the canvas does when no tool is
/// armed. So the bar holds only the four things you can ADD, an armed
/// one disarms on a second tap, and the row fits.
///
/// ## Why there is no Erase button
///
/// It was a destructive mode: arm it and every later tap deleted
/// something, an office taking its desks and seats with it. Deleting
/// belongs to a thing you have selected and can see, so it moved to
/// [EditorSelectionBar].
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.armed,
    required this.onArm,
  });

  /// The tool a drag or tap currently belongs to, or null — the resting
  /// state, where the canvas selects and pans.
  final EditorTool? armed;

  /// Arm a tool, or pass null to go back to selecting.
  final ValueChanged<EditorTool?> onArm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: AppSpacing.smAll,
        child: Row(
          children: [
            for (final (tool, icon, label) in [
              (
                EditorTool.office,
                Icons.meeting_room_outlined,
                l10n?.editorToolOffice ?? 'Office',
              ),
              (
                EditorTool.desk,
                Icons.table_restaurant_outlined,
                l10n?.editorToolDesk ?? 'Desk',
              ),
              (
                EditorTool.seat,
                Icons.chair_outlined,
                l10n?.editorToolSeat ?? 'Seat',
              ),
              (
                EditorTool.image,
                Icons.add_photo_alternate_outlined,
                l10n?.editorToolImage ?? 'Image',
              ),
            ])
              Expanded(
                child: _ToolButton(
                  tool: tool,
                  icon: icon,
                  label: label,
                  armed: armed == tool,
                  // A second tap on the armed tool puts the canvas back
                  // to selecting — the way out of a mode is the same
                  // button that got you in.
                  onTap: () => onArm(armed == tool ? null : tool),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.icon,
    required this.label,
    required this.armed,
    required this.onTap,
  });

  final EditorTool tool;
  final IconData icon;
  final String label;
  final bool armed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: armed,
      child: Material(
        color: armed ? scheme.primary : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          key: ValueKey('editor-tool-${tool.name}'),
          borderRadius: AppRadius.mdAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: armed ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            armed ? scheme.onPrimary : scheme.onSurfaceVariant,
                        fontWeight: armed ? FontWeight.w600 : null,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
