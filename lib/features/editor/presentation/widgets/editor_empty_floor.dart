// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// The first thing to do on a floor nobody has drawn yet (#1216): an
/// empty floor used to be a blank grid under a row of tools, which says
/// what you CAN do and never what to do first.
class EditorEmptyFloor extends StatelessWidget {
  const EditorEmptyFloor({required this.onStart, super.key});

  /// Arms the office tool.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: AppSpacing.xlAll,
        child: SingleChildScrollView(
          primary: false,
          child: Card(
            key: const ValueKey('editor-empty-floor'),
            child: Padding(
              padding: AppSpacing.lgAll,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.editorEmptyFloorTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.editorEmptyFloorBody,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('editor-empty-floor-start'),
                    onPressed: onStart,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.editorEmptyFloorAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
