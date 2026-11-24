// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
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

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final title = TextEditingController();
    final url = TextEditingController();
    var category = 'other';
    var provider = 'link';
    var minRole = 'member';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.documentsAdd),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('document-title'),
                  controller: title,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l10n.documentsTitleLabel,
                    counterText: '',
                    suffixIcon: HelpDot(l10n.helpTopicDocumentLibrary,
                      anchor: HelpAnchor.featureDocuments,
                    ),
                  ),
                ),
                TextField(
                  key: const ValueKey('document-url'),
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.documentsUrlLabel,
                    suffixIcon: HelpDot(l10n.helpTopicDocumentLibrary,
                      anchor: HelpAnchor.documentsUrl,
                    ),
                    helperMaxLines: 3,
                    helperText: l10n.documentsUrlHelper,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('document-provider'),
                      initialValue: provider,
                      items: [
                        for (final p in WorkspaceDocument.providers)
                          DropdownMenuItem(
                            value: p,
                            child: Row(children: [
                              Icon(providerIcon(p), size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Text(providerName(p)),
                            ]),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => provider = v ?? provider),
                      decoration: InputDecoration(
                        labelText:
                            l10n.documentsProviderLabel,
                      ),
                    ),
                  ),
                  HelpDot(l10n.helpTopicDocumentLibrary,
                    anchor: HelpAnchor.documentsProvider,
                  ),
                ]),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('document-category'),
                      initialValue: category,
                      items: [
                        for (final c in WorkspaceDocument.categories)
                          DropdownMenuItem(
                            value: c,
                            child: Text(categoryName(l10n, c)),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => category = v ?? category),
                      decoration: InputDecoration(
                        labelText:
                            l10n.moneyExpenseCategoryLabel,
                      ),
                    ),
                  ),
                  HelpDot(l10n.helpTopicDocumentLibrary,
                    anchor: HelpAnchor.documentsCategory,
                  ),
                ]),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('document-role'),
                      initialValue: minRole,
                      items: [
                        DropdownMenuItem(
                          value: 'member',
                          child: Text(
                              l10n.documentsRoleMember),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(l10n.documentsRoleAdmin),
                        ),
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text(
                              l10n.documentsRoleOwner),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => minRole = v ?? minRole),
                      decoration: InputDecoration(
                        labelText:
                            l10n.documentsRoleLabel,
                      ),
                    ),
                  ),
                  HelpDot(l10n.helpTopicDocumentLibrary,
                    anchor: HelpAnchor.documentsRole,
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('documents-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('document-save'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    if (title.text.trim().isEmpty ||
        !url.text.trim().startsWith('https://')) {
      AppSnack.error(
        context,
        l10n.documentsInvalid,
      );
      return;
    }
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'document add failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(workspaceRepositoryProvider).addDocument(
            WorkspaceDocument(
              id: '',
              workspaceId: workspace.id,
              title: title.text,
              category: category,
              provider: provider,
              url: url.text,
              minRole: minRole,
            ),
          ),
    )) {
      return;
    }
    ref.invalidate(workspaceDocumentsProvider);
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
          content: DropdownButtonFormField<String>(
            key: const ValueKey('document-audience-edit'),
            initialValue: minRole,
            items: [
              for (final r in WorkspaceDocument.roles)
                DropdownMenuItem(value: r, child: Text(audienceName(l10n, r))),
            ],
            onChanged: (v) => setState(() => minRole = v ?? minRole),
            decoration: InputDecoration(labelText: l10n.documentsRoleLabel),
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
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: FilledButton(
                key: const ValueKey('documents-add'),
                onPressed: () => _addDialog(context, ref),
                child: Text(l10n.documentsAdd),
              ),
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
