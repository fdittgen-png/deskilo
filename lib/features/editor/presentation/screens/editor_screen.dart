// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n?.editorLevelNameLabel ?? 'Level name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
}

/// Owner-only workspace editor (spec §10). This screen manages levels;
/// tapping a level opens its grid canvas (#34).
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final levelsAsync = ref.watch(levelsProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.editorTitle ?? 'Workspace editor'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: workspace == null
            ? null
            : () async {
                final name = await _promptName(
                  context,
                  title: l10n?.editorAddLevel ?? 'Add level',
                );
                if (name == null || name.isEmpty) return;
                final count = levelsAsync.value?.length ?? 0;
                await ref
                    .read(floorPlanRepositoryProvider)
                    .createLevel(workspace.id, name, count);
                ref.invalidate(levelsProvider);
              },
        icon: const Icon(Icons.add),
        label: Text(l10n?.editorAddLevel ?? 'Add level'),
      ),
      body: switch (levelsAsync) {
        AsyncData(value: final levels) when levels.isEmpty => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n?.editorNoLevels ??
                    'No levels yet. Add the first floor of your workspace.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        AsyncData(value: final levels) => _LevelList(levels: levels),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LevelList extends ConsumerWidget {
  const _LevelList({required this.levels});

  final List<Level> levels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ReorderableListView.builder(
      itemCount: levels.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        final ids = levels.map((l) => l.id).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, id);
        await ref.read(floorPlanRepositoryProvider).reorderLevels(ids);
        ref.invalidate(levelsProvider);
      },
      itemBuilder: (context, index) {
        final level = levels[index];
        return ListTile(
          key: ValueKey(level.id),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(level.name),
          onTap: () => context.push('/editor/level/${level.id}'),
          trailing: MenuAnchor(
            builder: (context, controller, child) => IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n?.editorLevelActions ?? 'Level actions',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
            menuChildren: [
              MenuItemButton(
                onPressed: () async {
                  final name = await _promptName(
                    context,
                    title: l10n?.editorRenameLevel ?? 'Rename',
                    initial: level.name,
                  );
                  if (name == null || name.isEmpty) return;
                  await ref
                      .read(floorPlanRepositoryProvider)
                      .renameLevel(level.id, name);
                  ref.invalidate(levelsProvider);
                },
                child: Text(l10n?.editorRenameLevel ?? 'Rename'),
              ),
              MenuItemButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n?.commonDelete ?? 'Delete'),
                      content: Text(
                        l10n?.editorDeleteLevelConfirm ??
                            'Delete this level? All offices, desks and '
                                'seats on it are removed.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(l10n?.commonCancel ?? 'Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(l10n?.commonDelete ?? 'Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref
                      .read(floorPlanRepositoryProvider)
                      .deleteLevel(level.id);
                  ref.invalidate(levelsProvider);
                },
                child: Text(l10n?.commonDelete ?? 'Delete'),
              ),
            ],
          ),
        );
      },
    );
  }
}
