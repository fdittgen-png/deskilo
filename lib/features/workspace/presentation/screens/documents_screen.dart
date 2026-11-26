// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_document.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/documents_table.dart';

/// The workspace DOCUMENT LIBRARY (#500): statutes, guides, financial
/// statements, minutes — links into whatever drive the workspace uses
/// (Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud, any URL).
/// Members see what their ROLE may see (RLS decides; the client just
/// renders what arrives). Admins/owners curate.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  static IconData providerIcon(String provider) => switch (provider) {
        'gdrive' => Icons.add_to_drive_outlined,
        'onedrive' => Icons.cloud_outlined,
        'sharepoint' => Icons.groups_2_outlined,
        'dropbox' => Icons.inventory_2_outlined,
        'nextcloud' => Icons.cloud_sync_outlined,
        _ => Icons.link_outlined,
      };

  static String providerName(String provider) => switch (provider) {
        // Product names — proper nouns, identical in every locale.
        'gdrive' => 'Google Drive',
        'onedrive' => 'OneDrive',
        'sharepoint' => 'SharePoint',
        'dropbox' => 'Dropbox',
        'nextcloud' => 'Nextcloud',
        _ => 'Link',
      };

  static String categoryName(AppLocalizations l10n, String category) =>
      switch (category) {
        'statutes' => l10n.documentsCategoryStatutes,
        'guides' => l10n.documentsCategoryGuides,
        'finance' =>
          l10n.documentsCategoryFinance,
        'minutes' => l10n.documentsCategoryMinutes,
        _ => l10n.documentsCategoryOther,
      };

  /// A choice of the add form with the help that explains it beside it.
  static Widget _choice(Widget field, String topic, String anchor) => Row(
    children: [
      Expanded(child: field),
      HelpDot(topic, anchor: anchor),
    ],
  );

  /// The add form: a link filed in the library. Each problem is said under
  /// its field and nothing typed is lost; the sheet closes once it is saved.
  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final fields = FormControllers();
    final topic = l10n.helpTopicDocumentLibrary;
    final failed = l10n.workspaceGenericError;
    var category = 'other';
    var provider = 'link';
    var minRole = 'member';
    final saved = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.documentsAdd,
        submitLabel: l10n.commonSave,
        submitKey: const ValueKey('document-save'),
        onDispose: fields.dispose,
        validate: () {
          final problems = documentLinkProblems(
            title: fields['title'].text,
            url: fields['url'].text,
          );
          return {
            if (problems.contains(DocumentLinkProblem.titleMissing))
              'title': l10n.documentsTitleMissing,
            if (problems.contains(DocumentLinkProblem.linkNotHttps))
              'url': l10n.documentsLinkNotHttps,
          };
        },
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'workspace',
            message: 'document add failed',
            errorText: failed,
            action: () => ref
                .read(workspaceRepositoryProvider)
                .addDocument(
                  WorkspaceDocument(
                    id: '',
                    workspaceId: workspace.id,
                    title: fields['title'].text,
                    category: category,
                    provider: provider,
                    url: fields['url'].text,
                    minRole: minRole,
                  ),
                ),
          );
          return ok ? null : failed;
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('document-title'),
            controller: fields['title'],
            fieldKey: 'title',
            label: l10n.documentsTitleLabel,
            maxLength: 120,
            help: HelpDot(topic, anchor: HelpAnchor.featureDocuments),
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('document-url'),
            controller: fields['url'],
            fieldKey: 'url',
            label: l10n.documentsUrlLabel,
            helper: l10n.documentsUrlHelper,
            keyboardType: TextInputType.url,
            autofillHints: const [AutofillHints.url],
            help: HelpDot(topic, anchor: HelpAnchor.documentsUrl),
          ),
          const FormGap(),
          _choice(
            AppDropdownField<String>(
              key: const ValueKey('document-provider'),
              label: l10n.documentsProviderLabel,
              value: provider,
              items: [
                for (final p in WorkspaceDocument.providers)
                  (p, providerName(p)),
              ],
              onChanged: (v) {
                provider = v ?? provider;
                refresh();
              },
            ),
            topic,
            HelpAnchor.documentsProvider,
          ),
          const FormGap(),
          _choice(
            AppDropdownField<String>(
              key: const ValueKey('document-category'),
              label: l10n.moneyExpenseCategoryLabel,
              value: category,
              items: [
                for (final c in WorkspaceDocument.categories)
                  (c, categoryName(l10n, c)),
              ],
              onChanged: (v) {
                category = v ?? category;
                refresh();
              },
            ),
            topic,
            HelpAnchor.documentsCategory,
          ),
          const FormGap(),
          _choice(
            AppDropdownField<String>(
              key: const ValueKey('document-role'),
              label: l10n.documentsRoleLabel,
              value: minRole,
              items: [
                for (final r in WorkspaceDocument.roles)
                  (r, audienceName(l10n, r)),
              ],
              onChanged: (v) {
                minRole = v ?? minRole;
                refresh();
              },
            ),
            topic,
            HelpAnchor.documentsRole,
          ),
        ],
      ),
    );
    if (saved) ref.invalidate(workspaceDocumentsProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    WorkspaceDocument document,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.documentsDelete),
        content: Text(document.title),
        actions: [
          TextButton(
            key: const ValueKey('documents-cancel-2'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('document-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'document delete failed',
      errorText: l10n.workspaceGenericError,
      action: () =>
          ref.read(workspaceRepositoryProvider).deleteDocument(document.id),
    )) {
      return;
    }
    ref.invalidate(workspaceDocumentsProvider);
  }

  /// #4070 — Edit audience: one choice of who sees the document.
  Future<void> _editAudience(
    BuildContext context,
    WidgetRef ref,
    WorkspaceDocument document,
  ) async {
    final l10n = context.l10n;
    var minRole = WorkspaceDocument.roles.contains(document.minRole)
        ? document.minRole
        : 'member';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.documentsEditAudience),
          content: AppDropdownField<String>(
            key: const ValueKey('document-audience-edit'),
            label: l10n.documentsRoleLabel,
            value: minRole,
            items: [
              for (final r in WorkspaceDocument.roles)
                (r, audienceName(l10n, r)),
            ],
            onChanged: (v) => setState(() => minRole = v ?? minRole),
          ),
          actions: [
            TextButton(
              key: const ValueKey('document-audience-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('document-audience-save'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted || minRole == document.minRole) {
      return;
    }
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'document audience change failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref
          .read(workspaceRepositoryProvider)
          .setDocumentAudience(document.id, minRole),
    )) {
      return;
    }
    ref.invalidate(workspaceDocumentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #2137 — whoever manages the library curates it, through a role too.
    final canCurate = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageDocuments);
    return Scaffold(
      appBar: pageBar(
        context,
        title: l10n.featureDocuments,
        actions: [
          if (canCurate)
            pageBarAction(
              key: const ValueKey('documents-add'),
              label: l10n.documentsAdd,
              onPressed: () => _addDialog(context, ref),
            ),
        ],
      ),
      body: DocumentsTable(
        read: ref.watch(workspaceDocumentsProvider),
        canCurate: canCurate,
        onOpen: (d) => ref.read(linkLauncherProvider)(Uri.parse(d.url)),
        onEditAudience: (d) => unawaited(_editAudience(context, ref, d)),
        onDelete: (d) => unawaited(_delete(context, ref, d)),
        onRetry: () => ref.invalidate(workspaceDocumentsProvider),
      ),
    );
  }
}
