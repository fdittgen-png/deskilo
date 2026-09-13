// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan_editing.dart';

/// What the canvas offers for the thing you have selected (#1216).
///
/// This is where Delete lives now. As a tool it was a mode: arm Erase
/// and every later tap removed something, an office taking its desks
/// and seats with it, with a confirm dialog as the only thing between a
/// forgotten mode and a lost floor.
///
/// Here it acts on one named element that is outlined on the canvas in
/// front of you — you can see what you are about to lose before you ask
/// to lose it, which is the whole difference.
class EditorSelectionBar extends StatelessWidget {
  const EditorSelectionBar({
    super.key,
    required this.kind,
    required this.name,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onDismiss,
  });

  final ElementKind kind;

  /// The element's own name, so the bar says what it acts on.
  final String name;

  /// Null when this kind has no properties (a plan image).
  final VoidCallback? onEdit;

  /// Null when this kind cannot be duplicated.
  final VoidCallback? onDuplicate;

  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('editor-selection-dismiss'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
              Expanded(
                child: Text(
                  name,
                  key: const ValueKey('editor-selection-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onDuplicate != null)
                IconButton(
                  key: const ValueKey('editor-selection-duplicate'),
                  tooltip: l10n?.editorDuplicate ?? 'Duplicate',
                  icon: const Icon(Icons.content_copy_outlined),
                  onPressed: onDuplicate,
                ),
              if (onEdit != null)
                IconButton(
                  key: const ValueKey('editor-selection-edit'),
                  tooltip: l10n?.editorProperties ?? 'Properties',
                  icon: const Icon(Icons.tune),
                  onPressed: onEdit,
                ),
              IconButton(
                key: const ValueKey('editor-selection-delete'),
                tooltip: l10n?.commonDelete ?? 'Delete',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
