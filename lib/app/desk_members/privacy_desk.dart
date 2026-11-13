// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3628 (desk M9) — the members' rights requests at the desk: a records
// table (#3606) of who asked, what, when it came in and where it stands,
// with Open and Answered as chips; a request opens beside the table at its
// address, `/members/privacy/<id>` (#3607), with the same card, the same
// actions and the same refusals as on a phone. Recording a request and an
// incident stay the page's two actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/l10n/rights_labels.dart';
import '../../core/navigation/list_detail_route.dart';
import '../../core/storage/pane_width_store.dart';
import '../../core/ui/kit/list_detail_scaffold.dart';
import '../../core/ui/kit/records_table.dart';
import '../../features/members/presentation/screens/privacy_admin_screen.dart';
import '../../features/profile/application/privacy_admin.dart';

/// The requests' address; a request is `/members/privacy/<id>`.
const String _privacyRequestsPath = '/members/privacy';

/// Whether [request] still waits for an answer.
bool _open(RightsRequest request) =>
    request.status == 'received' || request.status == 'extended';

/// The requests table, with the open request beside it.
class PrivacyDesk extends ConsumerWidget {
  const PrivacyDesk({super.key, required this.space});

  final PrivacyAdminSpace space;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OpenRecord(
    listPath: _privacyRequestsPath,
    builder: (context, id) => ListDetailScaffold(
      id: 'privacy-requests',
      paneStore: ref.watch(paneWidthStoreProvider),
      list: _table(context, ref),
      selected: recordBesideList(context) ? id : null,
      onClose: () => closeRecord(context, _privacyRequestsPath),
      onMove: (id) => moveToRecord(context, _privacyRequestsPath, id),
      detail: (context, id) => PrivacyRequestRecord(
        key: ValueKey('privacy-request-panel-$id'),
        requestId: id,
        onClose: () => closeRecord(context, _privacyRequestsPath),
      ),
    ),
  );

  Widget _table(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = appFormatOf(context).dates(DateShape.date);
    final read = ref.watch(workspaceRightsRequestsProvider(space.id));
    final names = {for (final m in space.members) m.id: m.name};
    return RecordsTable<RightsRequest>(
      tableId: 'privacy-requests',
      rows: read.value ?? const <RightsRequest>[], // empty-ok: the table shows loading or failed while it is not read
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(workspaceRightsRequestsProvider(space.id)),
      keyOf: (r) => r.id,
      searchText: (r) =>
          '${names[r.memberId] ?? ''} ${rightsKindLabel(l, r.kind)} ${r.details}',
      onOpen: (r) => openRecord(context, _privacyRequestsPath, r.id),
      empty: Center(
        child: Text(
          l.privacyAdminEmpty,
          key: const ValueKey('privacy-admin-empty'),
        ),
      ),
      initialQuery: const RecordsQuery(
        chip: 'open',
        sortColumn: 'received',
        ascending: false,
      ),
      chips: [
        RecordChip(id: 'open', label: l.privacyRequestsOpen, keeps: _open),
        RecordChip(
          id: 'answered',
          label: l.privacyRequestsAnswered,
          keeps: (r) => !_open(r),
        ),
      ],
      columns: [
        RecordColumn(
          id: 'who',
          label: l.privacyRequestsColWho,
          flex: 3,
          hideable: false,
          sortKey: (r) => (names[r.memberId] ?? '').toLowerCase(),
          cell: (_, r) =>
              Text(names[r.memberId] ?? '', overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'kind',
          label: l.privacyRequestsColKind,
          flex: 3,
          sortKey: (r) => r.kind,
          cell: (_, r) => Text(rightsKindLabel(l, r.kind)),
        ),
        RecordColumn(
          id: 'received',
          label: l.privacyRequestsColReceived,
          flex: 2,
          staysBeside: false,
          sortKey: (r) => r.receivedAt,
          cell: (_, r) => Text(dates.format(r.receivedAt)),
        ),
        RecordColumn(
          id: 'status',
          label: l.privacyRequestsColStatus,
          flex: 4,
          sortKey: (r) => r.extendedDueOn ?? r.dueOn,
          cell: (_, r) => Text(
            rightsStatusLabel(
              l,
              status: r.status,
              dueOn: r.dueOn,
              answerBy: r.answerBy,
              date: dates,
              extensionReason: r.extensionReason,
              refusalReason: r.refusalReason,
            ),
          ),
        ),
      ],
      cardBuilder: (context, r) => ListTile(
        key: ValueKey('privacy-request-card-${r.id}'),
        title: Text(names[r.memberId] ?? ''),
        subtitle: Text(rightsKindLabel(l, r.kind)),
      ),
    );
  }
}

/// A rights request at its address: the card with its actions.
class PrivacyRequestRecord extends ConsumerWidget {
  const PrivacyRequestRecord({
    super.key,
    required this.requestId,
    this.onClose,
  });

  final String requestId;

  /// Set when the request stands beside the table: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final space = ref.watch(privacyAdminSpaceProvider);
    final requests = space == null
        ? null
        : ref.watch(workspaceRightsRequestsProvider(space.id)).value;
    final request = requests?.where((r) => r.id == requestId).firstOrNull;
    final names = <String, String>{
      for (final m in space?.members ?? const <({String id, String name})>[])
        m.id: m.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(request == null ? '' : rightsKindLabel(l, request.kind)),
        automaticallyImplyLeading: onClose == null,
        actions: [
          if (onClose case final close?)
            CloseButton(
              key: const ValueKey('privacy-request-close'),
              onPressed: close,
            ),
        ],
      ),
      // A request the reader cannot read, or none of that id, is said in
      // words; nothing is shown as if it were theirs.
      body: requests != null && request == null
          ? Center(
              child: Text(
                l.searchRecordUnreadable,
                key: const ValueKey('search-record-unreadable'),
              ),
            )
          : request == null
          ? const SizedBox.shrink()
          : ListView(
              children: [
                RightsRequestCard(
                  request: request,
                  who: names[request.memberId] ?? '',
                  date: appFormatOf(context).dates(DateShape.date),
                ),
              ],
            ),
    );
  }
}
