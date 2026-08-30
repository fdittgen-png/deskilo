// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_document.dart';
import '../../providers/workspace_providers.dart';

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

  static String categoryName(AppLocalizations? l10n, String category) =>
      switch (category) {
        'statutes' => l10n?.documentsCategoryStatutes ?? 'Statutes & legal',
        'guides' => l10n?.documentsCategoryGuides ?? 'Guides & manuals',
        'finance' =>
          l10n?.documentsCategoryFinance ?? 'Financial statements',
        'minutes' => l10n?.documentsCategoryMinutes ?? 'Meeting minutes',
        _ => l10n?.documentsCategoryOther ?? 'Other documents',
      };

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
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
          title: Text(l10n?.documentsAdd ?? 'Add a document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('document-title'),
                  controller: title,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l10n?.documentsTitleLabel ?? 'Title',
                    counterText: '',
                    suffixIcon: HelpDot(l10n?.helpTopicDocumentLibrary ??
                        'document library'),
                  ),
                ),
                TextField(
                  key: const ValueKey('document-url'),
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n?.documentsUrlLabel ?? 'Link (https://…)',
                    suffixIcon: HelpDot(l10n?.helpTopicDocumentLibrary ??
                        'document library'),
                    helperMaxLines: 3,
                    helperText: l10n?.documentsUrlHelper ??
                        'Paste the share link from your drive — access '
                            'rights stay managed there.',
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
                              const SizedBox(width: 8),
                              Text(providerName(p)),
                            ]),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => provider = v ?? provider),
                      decoration: InputDecoration(
                        labelText:
                            l10n?.documentsProviderLabel ?? 'Stored on',
                      ),
                    ),
                  ),
                  HelpDot(l10n?.helpTopicDocumentLibrary ??
                      'document library'),
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
                            l10n?.documentsCategoryLabel ?? 'Category',
                      ),
                    ),
                  ),
                  HelpDot(l10n?.helpTopicDocumentLibrary ??
                      'document library'),
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
                              l10n?.documentsRoleMember ?? 'Every member'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(l10n?.documentsRoleAdmin ??
                              'Admins and owners'),
                        ),
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text(
                              l10n?.documentsRoleOwner ?? 'Owners only'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => minRole = v ?? minRole),
                      decoration: InputDecoration(
                        labelText:
                            l10n?.documentsRoleLabel ?? 'Visible to',
                      ),
                    ),
                  ),
                  HelpDot(l10n?.helpTopicDocumentLibrary ??
                      'document library'),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n?.commonCancel ?? 'Cancel'),
            ),
            FilledButton(
              key: const ValueKey('document-save'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n?.commonSave ?? 'Save'),
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
        l10n?.documentsInvalid ??
            'A document needs a title and an https:// link.',
      );
      return;
    }
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'document add failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.documentsDelete ?? 'Remove document?'),
        content: Text(document.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('document-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.commonDelete ?? 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'document delete failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(workspaceRepositoryProvider).deleteDocument(document.id),
    )) {
      return;
    }
    ref.invalidate(workspaceDocumentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final documentsAsync = ref.watch(workspaceDocumentsProvider);
    final canCurate =
        ref.watch(myMemberProvider).value?.canAdminister ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.documentsTitle ?? 'Documents'),
      ),
      floatingActionButton: canCurate
          ? FloatingActionButton(
              key: const ValueKey('documents-add'),
              onPressed: () => _addDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: switch (documentsAsync) {
        AsyncData(value: final documents) => documents.isEmpty
            ? EmptyState(
                icon: Icons.folder_open_outlined,
                title: l10n?.documentsEmpty ??
                    'No document yet. Link your statutes, guides and '
                        'statements from any drive.',
              )
            : ListView(
                padding: AppSpacing.gutterAll,
                children: [
                  for (final category in WorkspaceDocument.categories)
                    if (documents.any((d) => d.category == category)) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppSpacing.sm, bottom: AppSpacing.xs),
                        child: Text(
                          categoryName(l10n, category),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final document in documents
                          .where((d) => d.category == category))
                        ListTile(
                          key: ValueKey('document-${document.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(providerIcon(document.provider)),
                          title: Text(document.title),
                          subtitle: Row(children: [
                            Text(providerName(document.provider)),
                            if (document.minRole != 'member') ...[
                              const SizedBox(width: 6),
                              Icon(Icons.lock_outline,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              Text(
                                document.minRole == 'owner'
                                    ? (l10n?.documentsRoleOwner ??
                                        'Owners only')
                                    : (l10n?.documentsRoleAdmin ??
                                        'Admins and owners'),
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ]),
                          trailing: canCurate
                              ? IconButton(
                                  key: ValueKey(
                                      'document-delete-${document.id}'),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _delete(context, ref, document),
                                )
                              : const Icon(Icons.open_in_new, size: 18),
                          onTap: () => ref.read(linkLauncherProvider)(
                              Uri.parse(document.url)),
                        ),
                    ],
                ],
              ),
        AsyncError() => Center(
            child: Text(l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.'),
          ),
        _ => const LoadingView(),
      },
    );
  }
}
