// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// The level's background image menu (0036): set or replace it, and
/// remove it when there is one.
class LevelBackgroundMenu extends StatelessWidget {
  const LevelBackgroundMenu({
    required this.hasBackground,
    required this.onSet,
    required this.onRemove,
    super.key,
  });

  final bool hasBackground;
  final VoidCallback onSet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      key: const ValueKey('level-canvas-editor-background-image'),
      icon: const Icon(Icons.image_outlined),
      tooltip: l10n.editorBackgroundImage,
      onSelected: (v) => v == 'set' ? onSet() : onRemove(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'set',
          child: Text(
            hasBackground
                ? l10n.editorBackgroundReplace
                : l10n.editorBackgroundSet,
          ),
        ),
        if (hasBackground)
          PopupMenuItem(
            value: 'remove',
            child: Text(l10n.editorBackgroundRemove),
          ),
      ],
    );
  }
}
