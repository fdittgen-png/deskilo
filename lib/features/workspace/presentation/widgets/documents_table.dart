// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4070 — the document library as a records table: name, group, audience
// and the day it was added on a desk, a card per document on a phone, and
// one row menu (Open, Edit audience, Delete) on both. The page
// (documents_screen.dart) owns the bar and what each action does.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../core/ui/kit/row_menu.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_document.dart';
import '../screens/documents_screen.dart' show DocumentsScreen;

/// Who may read a document, as words on a tint: said on every row.
Widget audienceChip(AppLocalizations l10n, String minRole) => StatusChip(
  key: ValueKey('document-audience-$minRole'),
  label: audienceName(l10n, minRole),
  tone: minRole == 'member' ? StatusTone.neutral : StatusTone.warn,
);

/// The words for an audience ([minRole] is the lowest role that reads).
String audienceName(AppLocalizations l10n, String minRole) => switch (minRole) {
  'owner' => l10n.documentsRoleOwner,
  'admin' => l10n.documentsRoleAdmin,
  _ => l10n.documentsRoleMember,
};

/// #2327 — the shelf a document is listed under. A category this app does
/// not know (an older or newer client wrote it) is listed under "other"
/// rather than not at all: a library with rows must never render blank.
String documentShelf(WorkspaceDocument d) =>
    WorkspaceDocument.categories.contains(d.category) ? d.category : 'other';

/// The library's rows.
class DocumentsTable extends StatelessWidget {
  const DocumentsTable({
    required this.read,
    required this.canCurate,
    required this.onOpen,
    required this.onEditAudience,
    required this.onDelete,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<List<WorkspaceDocument>> read;

  /// Whether the person may change the library: Edit audience and Delete.
  final bool canCurate;
  final void Function(WorkspaceDocument document) onOpen;
  final void Function(WorkspaceDocument document) onEditAudience;
  final void Function(WorkspaceDocument document) onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    // The row menu: Open, Edit audience, Delete (which still asks).
    final actions = <_Entry>[
      _Entry('open', l10n.financesOpenDocument, Icons.open_in_new, onOpen),
      if (canCurate) ...[
        _Entry(
          'audience',
          l10n.documentsEditAudience,
          Icons.visibility_outlined,
          onEditAudience,
        ),
        _Entry(
          'delete',
          l10n.commonDelete,
          Icons.delete_outline,
          onDelete,
          destructive: true,
        ),
      ],
    ];
    String added(WorkspaceDocument d) => switch (d.system.createdAt) {
      final at? => format.dates(DateShape.numeric).format(at),
      null => '',
    };
    return RecordsTable<WorkspaceDocument>(
      tableId: 'documents',
      rows: read.value ?? const <WorkspaceDocument>[], // empty-ok: the table shows loading or failed while it is not read
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: onRetry,
      keyOf: (d) => d.id,
      searchText: (d) => d.title,
      onOpen: onOpen,
      empty: EmptyState(
        icon: Icons.folder_open_outlined,
        title: l10n.documentsEmpty,
      ),
      chips: [
        for (final r in WorkspaceDocument.roles)
          RecordChip<WorkspaceDocument>(
            id: r,
            label: audienceName(l10n, r),
            keeps: (d) => d.minRole == r,
          ),
      ],
      rowActions: (_) => [
        for (final a in actions)
          RecordAction<WorkspaceDocument>(
            id: a.id,
            label: a.label,
            icon: a.icon,
            destructive: a.destructive,
            onRun: a.run,
          ),
      ],
      columns: [
        RecordColumn(
          id: 'name',
          label: l10n.membersColName,
          flex: 4,
          hideable: false,
          sortKey: (d) => d.title.toLowerCase(),
          cell: (_, d) => Text(d.title, key: ValueKey('document-${d.id}')),
        ),
        RecordColumn(
          id: 'group',
          label: l10n.documentsColGroup,
          flex: 3,
          sortKey: documentShelf,
          cell: (_, d) =>
              Text(DocumentsScreen.categoryName(l10n, documentShelf(d))),
        ),
        RecordColumn(
          id: 'audience',
          label: l10n.documentsColAudience,
          flex: 3,
          cell: (_, d) => audienceChip(l10n, d.minRole),
        ),
        RecordColumn(
          id: 'added',
          label: l10n.documentsColAdded,
          flex: 2,
          sortKey: (d) => d.system.createdAt?.millisecondsSinceEpoch ?? 0,
          cell: (_, d) => Text(added(d)),
        ),
      ],
      cardBuilder: (context, d) => RowMenu(
        keyPrefix: 'document-menu-${d.id}',
        actions: [
          for (final a in actions)
            RowAction(
              id: a.id,
              label: a.label,
              icon: a.icon,
              destructive: a.destructive,
              // recorder-key-exempt: an entry of the menu, which keys it
              onSelected: () => a.run(d),
            ),
        ],
        child: ListTile(
          key: ValueKey('document-${d.id}'),
          title: Text(d.title),
          subtitle: Text(
            [
              DocumentsScreen.categoryName(l10n, documentShelf(d)),
              if (added(d).isNotEmpty) added(d),
            ].join(' · '),
          ),
          trailing: audienceChip(l10n, d.minRole),
        ),
      ),
    );
  }
}

/// One entry of a document's row menu.
class _Entry {
  const _Entry(
    this.id,
    this.label,
    this.icon,
    this.run, {
    this.destructive = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final void Function(WorkspaceDocument document) run;
  final bool destructive;
}
