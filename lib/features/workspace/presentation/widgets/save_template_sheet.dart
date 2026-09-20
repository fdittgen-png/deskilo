// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/publish_template.dart';
import '../../domain/template_preview.dart';
import '../../domain/template_publication.dart';
import '../../domain/workspace_template.dart';
import 'template_group_label.dart';

/// #1120 — snapshot this space as a template. The key is derived from the
/// name; a second save with the same name updates in place and bumps the
/// version. Everything is stripped SERVER-side.
///
/// #1280 S3 — flow C: before publishing, the owner chooses which groups
/// travel and sees, from the server's allow-list, what never does and which
/// names go with the plan (names are merge keys and cannot be stripped).
Future<void> showSaveTemplateSheet(
    BuildContext context, WidgetRef ref, String workspaceId) async {
  final l10n = AppLocalizations.of(context);
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SaveTemplateSheet(workspaceId: workspaceId),
  );
  if (saved == true && context.mounted) {
    AppSnack.success(context, l10n?.librarySaved ?? 'Saved to your templates.');
  }
}

class SaveTemplateSheet extends ConsumerStatefulWidget {
  const SaveTemplateSheet({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<SaveTemplateSheet> createState() => _SaveTemplateSheetState();
}

class _SaveTemplateSheetState extends ConsumerState<SaveTemplateSheet> {
  late final Future<TemplatePublication> _publication =
      publicationPreview(ref, widget.workspaceId);
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  var _visibility = TemplateVisibility.private;
  Set<TemplateGroup>? _groups;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  static String neverLabel(AppLocalizations? l10n, NeverPublished n) =>
      switch (n.entity) {
        'sites' => l10n?.libraryNeverSites ?? 'Sites and their addresses',
        'payment_instructions' => l10n?.libraryNeverPayment ?? 'Bank details',
        'document_design' =>
          l10n?.libraryNeverDocumentDesign ?? 'Document designs',
        'document_links' =>
          l10n?.libraryNeverDocumentLinks ?? 'Links to your documents',
        'invitations' => l10n?.libraryNeverInvitations ?? 'Invitation texts',
        _ => n.reason,
      };

  Future<void> _publish(TemplatePublication publication) async {
    final all = publication.groups.toSet();
    final chosen = _groups ?? all;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'save template failed',
      action: () => publishTemplate(
        ref,
        widget.workspaceId,
        name: _name.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        tags: [
          for (final t in _tags.text.split(','))
            if (t.trim().isNotEmpty) t.trim().toLowerCase(),
        ],
        groups: chosen.containsAll(all)
            ? null
            : ([for (final g in chosen) g.wire]..sort()),
      ),
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: FutureBuilder<TemplatePublication>(
        future: _publication,
        builder: (context, snap) {
          final publication = snap.data;
          if (publication == null && !snap.hasError) {
            return const SizedBox(height: 200, child: LoadingView());
          }
          final groups = publication?.groups ?? const <TemplateGroup>[];
          final chosen = _groups ??= groups.toSet();
          final strippedIdentity = publication?.published.any((p) =>
                  p.entity == 'identity' &&
                  chosen.contains(p.group) &&
                  p.stripped.isNotEmpty) ??
              false;
          final names = chosen.contains(TemplateGroup.space)
              ? publication?.planNames ?? const <String>[]
              : const <String>[];
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n?.librarySave ?? 'Save this space as a template',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('save-template-name'),
                  controller: _name,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: l10n?.librarySaveName ?? 'Template name'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('save-template-description'),
                  controller: _description,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: l10n?.librarySaveDescription ??
                          'Description (optional)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('save-template-tags'),
                  controller: _tags,
                  decoration: InputDecoration(
                      labelText:
                          l10n?.librarySaveTags ?? 'Tags, separated by commas'),
                ),
                if (publication != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n?.libraryPublishGroups ?? 'What travels',
                      style: theme.textTheme.titleSmall),
                  for (final g in groups)
                    CheckboxListTile(
                      key: ValueKey('save-template-group-${g.wire}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(templateGroupLabel(l10n, g)),
                      value: chosen.contains(g),
                      onChanged: (on) => setState(() =>
                          on == true ? chosen.add(g) : chosen.remove(g)),
                    ),
                  if (names.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n?.libraryPlanNames(names.join(', ')) ??
                          'These names go with the plan: ${names.join(', ')}',
                      key: const ValueKey('save-template-plan-names'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n?.libraryNeverPublished ?? 'Never published',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if (strippedIdentity)
                        l10n?.libraryNeverIdentity ??
                            'Your address, legal identifiers, legal mentions '
                                'and WhatsApp group',
                      for (final n in publication.neverPublished)
                        neverLabel(l10n, n),
                    ].join(' · '),
                    key: const ValueKey('save-template-never'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(l10n?.libraryVisibility ?? 'Who may see it',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(spacing: AppSpacing.sm, children: [
                  for (final v in [
                    TemplateVisibility.private,
                    TemplateVisibility.shared,
                    TemplateVisibility.public,
                  ])
                    ChoiceChip(
                      key: ValueKey('save-template-${v.name}'),
                      label: Text(switch (v) {
                        TemplateVisibility.private =>
                          l10n?.libraryVisibilityPrivate ?? 'Only me',
                        TemplateVisibility.shared =>
                          l10n?.libraryVisibilityShared ?? 'People I invite',
                        _ => l10n?.libraryVisibilityPublic ??
                            'Everyone (the library)',
                      }),
                      selected: _visibility == v,
                      onSelected: (_) => setState(() => _visibility = v),
                    ),
                ]),
                if (publication != null && chosen.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n?.libraryPublishNothing ?? 'Choose at least one group.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('save-template-confirm'),
                  onPressed: publication == null ||
                          chosen.isEmpty ||
                          _name.text.trim().isEmpty
                      ? null
                      : () => _publish(publication),
                  icon: const Icon(Icons.check),
                  label:
                      Text(MaterialLocalizations.of(context).saveButtonLabel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
