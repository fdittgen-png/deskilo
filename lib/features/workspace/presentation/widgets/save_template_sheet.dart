// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/publish_template.dart';
import '../../domain/invitation_message.dart';
import '../../domain/template_preview.dart';
import '../../domain/template_publication.dart';
import '../../domain/workspace_template.dart';
import 'template_group_label.dart';
import 'template_publish_summary.dart';

/// #1120 — snapshot this space as a template. The key is derived from the
/// name; a second save with the same name updates in place and bumps the
/// version. Everything is stripped SERVER-side.
///
/// #1280 S3 — flow C: before publishing, the owner chooses which groups
/// travel and sees, from the server's allow-list, what never does and which
/// names go with the plan (names are merge keys and cannot be stripped).
Future<void> showSaveTemplateSheet(
    BuildContext context, WidgetRef ref, String workspaceId) async {
  final l10n = context.l10n;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaveTemplateSheet(workspaceId: workspaceId),
  );
  if (saved == true && context.mounted) {
    AppSnack.success(context, l10n.librarySaved);
  }
}

class _SaveTemplateSheet extends ConsumerStatefulWidget {
  const _SaveTemplateSheet({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_SaveTemplateSheet> createState() => _SaveTemplateSheetState();
}

class _SaveTemplateSheetState extends ConsumerState<_SaveTemplateSheet> {
  late final Future<TemplatePublication> _publication =
      publicationPreview(ref, widget.workspaceId);
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  var _visibility = TemplateVisibility.private;
  Set<TemplateGroup>? _groups;
  // #1656 — invitation texts: an explicit choice, off until ticked.
  var _invitationTexts = false;
  var _wordingRefused = false;
  // #1658 — one request per opened sheet: a retry after a lost response
  // is the same publication, never a second version.
  late final String _requestId = newRequestId();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  static String neverLabel(AppLocalizations l10n, NeverPublished n) =>
      switch (n.entity) {
        'sites' => l10n.libraryNeverSites,
        'payment_instructions' => l10n.libraryNeverPayment,
        'document_design' =>
          l10n.libraryNeverDocumentDesign,
        'document_links' =>
          l10n.libraryNeverDocumentLinks,
        'invitations' => l10n.libraryNeverInvitations,
        _ => n.reason,
      };

  Future<void> _publish(TemplatePublication publication) async {
    final all = publication.groups.toSet();
    final chosen = _groups ?? all;
    final withTexts = _invitationTexts && chosen.contains(TemplateGroup.wording);
    setState(() => _wordingRefused = false);
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
        allGroups: [for (final g in all) g.wire],
        invitationTexts: withTexts,
        requestId: _requestId,
      ).catchError((Object e, StackTrace st) {
        // trace-exempt: shown in the sheet; any other failure rethrows.
        if (!isInvitationTextRefusal(e)) Error.throwWithStackTrace(e, st);
        if (mounted) setState(() => _wordingRefused = true);
        Error.throwWithStackTrace(e, st);
      }),
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                Text(l10n.librarySave,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('save-template-name'),
                  controller: _name,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: l10n.librarySaveName),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('save-template-description'),
                  controller: _description,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: l10n.librarySaveDescription),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const ValueKey('save-template-tags'),
                  controller: _tags,
                  decoration: InputDecoration(
                      labelText:
                          l10n.librarySaveTags),
                ),
                if (publication != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.libraryPublishGroups,
                      style: theme.textTheme.titleSmall),
                  TemplateProfileLine(chosen: chosen.length, total: groups.length),
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
                  if (chosen.contains(TemplateGroup.wording))
                    CheckboxListTile(
                      key: const ValueKey('save-template-invitations'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.libraryInvitationTexts),
                      subtitle: Text(l10n.libraryInvitationTextsHint(InvitationTags.workspaceName)),
                      value: _invitationTexts,
                      onChanged: (on) => setState(() => _invitationTexts = on == true),
                    ),
                  if (_wordingRefused)
                    Text(
                      l10n.libraryInvitationTextsRefused,
                      key: const ValueKey('save-template-invitations-refused'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  if (names.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.libraryPlanNames(names.join(', ')),
                      key: const ValueKey('save-template-plan-names'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.libraryNeverPublished,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if (strippedIdentity)
                        l10n.libraryNeverIdentity,
                      for (final n in publication.neverPublished)
                        neverLabel(l10n, n),
                    ].join(' · '),
                    key: const ValueKey('save-template-never'),
                    style: theme.textTheme.bodySmall,
                  ),
                  TemplateLocalNeedsPreview(workspaceId: widget.workspaceId),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(l10n.libraryVisibility,
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
                          l10n.libraryVisibilityPrivate,
                        TemplateVisibility.shared =>
                          l10n.libraryVisibilityShared,
                        _ => l10n.libraryVisibilityPublic,
                      }),
                      selected: _visibility == v,
                      onSelected: (_) => setState(() => _visibility = v),
                    ),
                ]),
                if (publication != null && chosen.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.libraryPublishNothing,
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
