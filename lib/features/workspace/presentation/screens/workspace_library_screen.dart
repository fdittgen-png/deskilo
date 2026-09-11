// SPDX-License-Identifier: 0BSD
//
// #1120 — the workspace library. Two halves on one screen:
//
//   * what you may START FROM — builtin, public, and what others shared
//     with your address — each applied by name, never wiping the plan;
//   * YOUR templates — the snapshots this space published, with who may
//     see them, the people invited, and a way to take one back.
//
// Every read and every write is the server's decision (0199): a grant
// row never proves access, and a snapshot never carries prices, storage
// paths or the site. The screen shows and asks; it does not decide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/workspace_template.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/save_template_sheet.dart';
import '../widgets/template_share_sheet.dart';

class WorkspaceLibraryScreen extends ConsumerWidget {
  const WorkspaceLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final me = ref.watch(myMemberProvider).value;
    final all = ref.watch(workspaceTemplatesProvider).value ?? const [];
    final mine = [for (final t in all) if (t.ownedBy(workspace?.id)) t];
    final library = [for (final t in all) if (!t.ownedBy(workspace?.id)) t];
    final canPublish = me?.actsAsOwner ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.libraryTitle ?? 'Workspace library')),
      floatingActionButton: canPublish && workspace != null
          ? FloatingActionButton.extended(
              key: const ValueKey('library-save'),
              onPressed: () => showSaveTemplateSheet(context, ref, workspace.id),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l10n?.librarySave ?? 'Save this space as a template'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n?.libraryStartFrom ?? 'Start from the library',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (library.isEmpty)
            Text(l10n?.libraryEmpty ?? 'Nothing here yet.',
                style: theme.textTheme.bodySmall),
          for (final t in library)
            _TemplateTile(
              template: t,
              trailing: canPublish && workspace != null
                  ? TextButton(
                      key: ValueKey('library-apply-${t.key}'),
                      onPressed: () => _apply(context, ref, workspace.id, t),
                      child: Text(l10n?.libraryApply ?? 'Apply to this space'),
                    )
                  : null,
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n?.libraryYours ?? 'Your templates',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (mine.isEmpty)
            Text(l10n?.libraryEmpty ?? 'Nothing here yet.',
                style: theme.textTheme.bodySmall),
          for (final t in mine)
            _TemplateTile(
              template: t,
              trailing: canPublish
                  ? PopupMenuButton<String>(
                      key: ValueKey('library-menu-${t.key}'),
                      onSelected: (v) => _menu(context, ref, t, v),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'share',
                            child: Text(l10n?.libraryShare ?? 'Share…')),
                        PopupMenuItem(
                            value: 'private',
                            child: Text(l10n?.libraryVisibilityPrivate ?? 'Only me')),
                        PopupMenuItem(
                            value: 'shared',
                            child: Text(l10n?.libraryVisibilityShared ?? 'People I invite')),
                        PopupMenuItem(
                            value: 'public',
                            child: Text(l10n?.libraryVisibilityPublic ?? 'Everyone (the library)')),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text(l10n?.libraryDelete ?? 'Delete template')),
                      ],
                    )
                  : null,
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, String workspaceId,
      WorkspaceTemplate t) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.libraryApplyConfirmTitle(t.name) ?? 'Apply « ${t.name} »?'),
        content: Text(l10n?.libraryApplyConfirmBody ??
            'Levels, rooms, desks and seats are added or updated by name. '
                'Nothing you already have is removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(
              key: const ValueKey('library-apply-confirm'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n?.libraryApply ?? 'Apply to this space')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await runGuarded(
      context,
      domain: 'workspace',
      message: 'apply template failed',
      action: () => ref
          .read(workspaceRepositoryProvider)
          .applyWorkspaceTemplate(workspaceId, t.id),
    )) {
      ref.invalidate(levelsProvider);
      if (context.mounted) {
        AppSnack.success(context, l10n?.libraryApplied ?? 'Template applied.');
      }
    }
  }

  Future<void> _menu(BuildContext context, WidgetRef ref,
      WorkspaceTemplate t, String action) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(workspaceRepositoryProvider);
    switch (action) {
      case 'share':
        await showTemplateShareSheet(context, ref, t);
      case 'private':
      case 'shared':
      case 'public':
        final v = TemplateVisibility.values.byName(action);
        if (await runGuarded(context,
            domain: 'workspace',
            message: 'template visibility failed',
            action: () => repo.setWorkspaceTemplateVisibility(t.id, v))) {
          ref.invalidate(workspaceTemplatesProvider);
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n?.libraryDelete ?? 'Delete template'),
            content: Text(l10n?.libraryDeleteConfirm(t.name) ??
                'Delete « ${t.name} »? People you shared it with lose access.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
              FilledButton(
                  key: const ValueKey('library-delete-confirm'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(MaterialLocalizations.of(ctx).deleteButtonTooltip)),
            ],
          ),
        );
        if (ok == true && context.mounted &&
            await runGuarded(context,
                domain: 'workspace',
                message: 'delete template failed',
                action: () => repo.deleteWorkspaceTemplate(t.id))) {
          ref.invalidate(workspaceTemplatesProvider);
        }
    }
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, this.trailing});
  final WorkspaceTemplate template;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = template.counts;
    final visibility = switch (template.visibility) {
      TemplateVisibility.builtin => l10n?.libraryVisibilityBuiltin ?? 'Built in',
      TemplateVisibility.private => l10n?.libraryVisibilityPrivate ?? 'Only me',
      TemplateVisibility.shared => l10n?.libraryVisibilityShared ?? 'People I invite',
      TemplateVisibility.public => l10n?.libraryVisibilityPublic ?? 'Everyone (the library)',
      TemplateVisibility.unknown => '',
    };
    return Card(
      child: ListTile(
        key: ValueKey('library-template-${template.key}'),
        leading: const Icon(Icons.grid_view_outlined),
        title: Text(template.name),
        subtitle: Text([
          l10n?.libraryCounts(c.levels, c.desks, c.seats) ??
              '${c.levels} levels · ${c.desks} desks · ${c.seats} seats',
          if (template.description.isNotEmpty) template.description,
          if (visibility.isNotEmpty) visibility,
        ].join('\n')),
        isThreeLine: template.description.isNotEmpty,
        trailing: trailing,
      ),
    );
  }
}
