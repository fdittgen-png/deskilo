// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_template.dart';
import '../../providers/workspace_providers.dart';

/// #1120 — snapshot this space's floor plan as a template. The key is
/// derived from the name; a second save with the same name updates in
/// place. Prices, storage paths and the site are stripped SERVER-side.
Future<void> showSaveTemplateSheet(
    BuildContext context, WidgetRef ref, String workspaceId) async {
  final l10n = AppLocalizations.of(context);
  final name = TextEditingController();
  final description = TextEditingController();
  var visibility = TemplateVisibility.private;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n?.librarySave ?? 'Save this space as a template',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('save-template-name'),
              controller: name,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: l10n?.librarySaveName ?? 'Template name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('save-template-description'),
              controller: description,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: l10n?.librarySaveDescription ?? 'Description (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n?.libraryVisibility ?? 'Who may see it',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: AppSpacing.sm, children: [
              for (final v in [TemplateVisibility.private, TemplateVisibility.shared, TemplateVisibility.public])
                ChoiceChip(
                  key: ValueKey('save-template-${v.name}'),
                  label: Text(switch (v) {
                    TemplateVisibility.private => l10n?.libraryVisibilityPrivate ?? 'Only me',
                    TemplateVisibility.shared => l10n?.libraryVisibilityShared ?? 'People I invite',
                    _ => l10n?.libraryVisibilityPublic ?? 'Everyone (the library)',
                  }),
                  selected: visibility == v,
                  onSelected: (_) => setState(() => visibility = v),
                ),
            ]),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('save-template-confirm'),
              onPressed: () => Navigator.of(ctx).pop(name.text.trim().isNotEmpty),
              icon: const Icon(Icons.check),
              label: Text(MaterialLocalizations.of(ctx).saveButtonLabel),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  if (await runGuarded(
    context,
    domain: 'workspace',
    message: 'save template failed',
    action: () => ref.read(workspaceRepositoryProvider).saveWorkspaceAsTemplate(
          workspaceId,
          key: templateKeyFrom(name.text),
          name: name.text.trim(),
          description: description.text.trim(),
          visibility: visibility,
        ),
  )) {
    ref.invalidate(workspaceTemplatesProvider);
    if (context.mounted) {
      AppSnack.success(context, l10n?.librarySaved ?? 'Saved to your templates.');
    }
  }
}
