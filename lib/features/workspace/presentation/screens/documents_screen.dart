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

  /// One choice of the add form, with the help that explains it beside it.
  static Widget _choice({
    required String keyName,
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onPicked,
    required Widget help,
  }) => Row(
    children: [
      Expanded(
        child: AppDropdownField<String>(
          key: ValueKey(keyName),
          label: label,
          value: value,
          items: items,
          onChanged: (v) {
            if (v != null) onPicked(v);
          },
        ),
      ),
      help,
    ],
  );

  /// The fields of the add form over [draft]; [refresh] redraws a choice.
  static List<Widget> _addFields(
    AppLocalizations l10n,
    _AddDraft draft,
    VoidCallback refresh,
  ) {
    final topic = l10n.helpTopicDocumentLibrary;
    return [
      AppTextField(
        key: const ValueKey('document-title'),
        controller: draft.title,
        fieldKey: _AddDraft.titleField,
        label: l10n.documentsTitleLabel,
        maxLength: 120,
        help: HelpDot(topic, anchor: HelpAnchor.featureDocuments),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('document-url'),
        controller: draft.url,
        fieldKey: _AddDraft.urlField,
        label: l10n.documentsUrlLabel,
        helper: l10n.documentsUrlHelper,
        keyboardType: TextInputType.url,
        autofillHints: const [AutofillHints.url],
        help: HelpDot(topic, anchor: HelpAnchor.documentsUrl),
      ),
      const FormGap(),
      _choice(
        keyName: 'document-provider',
        label: l10n.documentsProviderLabel,
        value: draft.provider,
        items: [
          for (final p in WorkspaceDocument.providers) (p, providerName(p)),
        ],
        onPicked: (v) {
          draft.provider = v;
          refresh();
        },
        help: HelpDot(topic, anchor: HelpAnchor.documentsProvider),
      ),
      const FormGap(),
      _choice(
        keyName: 'document-category',
        label: l10n.moneyExpenseCategoryLabel,
        value: draft.category,
        items: [
          for (final c in WorkspaceDocument.categories)
            (c, categoryName(l10n, c)),
        ],
        onPicked: (v) {
          draft.category = v;
          refresh();
        },
        help: HelpDot(topic, anchor: HelpAnchor.documentsCategory),
      ),
      const FormGap(),
      _choice(
        keyName: 'document-role',
        label: l10n.documentsRoleLabel,
        value: draft.minRole,
        items: [
          for (final r in WorkspaceDocument.roles) (r, audienceName(l10n, r)),
        ],
        onPicked: (v) {
          draft.minRole = v;
          refresh();
        },
        help: HelpDot(topic, anchor: HelpAnchor.documentsRole),
      ),
    ];
  }

  /// The add form: a link filed in the library. Each problem is said under
  /// its field and nothing typed is lost; the sheet closes once it is saved.
  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final draft = _AddDraft();
    final failed = l10n.workspaceGenericError;
    final saved = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.documentsAdd,
        submitLabel: l10n.commonSave,
        submitKey: const ValueKey('document-save'),
        onDispose: draft.dispose,
        validate: () => draft.problems(l10n),
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'workspace',
            message: 'document add failed',
            errorText: failed,
            action: () => ref
                .read(workspaceRepositoryProvider)
                .addDocument(draft.entry(workspace.id)),
          );
          return ok ? null : failed;
        },
        builder: (context, refresh) => _addFields(l10n, draft, refresh),
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

/// What the add form holds while it is open: the two typed values and the
/// three choices, the entry they make and what is still wrong with it.
class _AddDraft {
  /// The keys the two fields' problems are said under.
  static const String titleField = 'title';
  static const String urlField = 'url';

  final TextEditingController title = TextEditingController();
  final TextEditingController url = TextEditingController();
  String category = 'other';
  String provider = 'link';
  String minRole = 'member';

  void dispose() {
    title.dispose();
    url.dispose();
  }

  /// Each problem under the key of its field; empty when the entry may be
  /// filed.
  FieldErrors problems(AppLocalizations l10n) {
    final found = documentLinkProblems(title: title.text, url: url.text);
    return {
      if (found.contains(DocumentLinkProblem.titleMissing))
        titleField: l10n.documentsTitleMissing,
      if (found.contains(DocumentLinkProblem.linkNotHttps))
        urlField: l10n.documentsLinkNotHttps,
    };
  }

  /// The entry as it is filed in [workspaceId]'s library.
  WorkspaceDocument entry(String workspaceId) => WorkspaceDocument(
    id: '',
    workspaceId: workspaceId,
    title: title.text,
    category: category,
    provider: provider,
    url: url.text,
    minRole: minRole,
  );
}
