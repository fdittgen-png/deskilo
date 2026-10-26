// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/accounting_connection.dart';
import '../../../features/money/domain/accounting_target.dart';
import '../../../features/money/domain/book_period.dart';
import 'book_period_repository.dart';

/// The accounting connections in memory, with the server's rules the
/// screens show: one live connection per issuer and target, a token is
/// kept and never read back, a revoked connection keeps its mappings and
/// deliveries, a document a file carried with the same digest changes
/// nothing. No target is reached: a sign-in answers that the demo has no
/// application registered with it.
class FakeAccountingConnectionRepository
    implements AccountingConnectionRepository {
  FakeAccountingConnectionRepository({
    required this.books,
    required this.today,
    Iterable<AccountingConnection> connections = const [],
    Iterable<AccountingDelivery> deliveries = const [],
  }) : connections = [...connections],
       deliveries = [...deliveries];

  /// The export log the files of the transfers are read from.
  final FakeBookPeriodRepository books;
  final DateTime today;
  final List<AccountingConnection> connections;
  final List<AccountingDelivery> deliveries;
  var _next = 1;

  int _index(String connectionId) {
    final i = connections.indexWhere((c) => c.id == connectionId);
    if (i < 0) throw StateError('unknown connection');
    return i;
  }

  AccountingConnection _replace(
    AccountingConnection c, {
    ConnectionStatus? status,
    String? remoteTenantId,
    List<String>? secretsSet,
    List<AccountingMap>? maps,
    DateTime? revokedAt,
  }) {
    final next = AccountingConnection(
      id: c.id,
      issuerSiteId: c.issuerSiteId,
      targetId: c.targetId,
      authKind: c.authKind,
      status: status ?? c.status,
      remoteTenantId: remoteTenantId ?? c.remoteTenantId,
      displayName: c.displayName,
      connectedAt: status == ConnectionStatus.connected ? today : c.connectedAt,
      revokedAt: revokedAt ?? c.revokedAt,
      secretsSet: secretsSet ?? c.secretsSet,
      maps: maps ?? c.maps,
    );
    connections[_index(c.id)] = next;
    return next;
  }

  @override
  Future<List<AccountingConnection>> fetchConnections(
    String workspaceId,
  ) async => [
    for (final c in connections)
      if (c.live) c,
    for (final c in connections)
      if (!c.live) c,
  ];

  @override
  Future<AccountingConnection> openTokenConnection(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
  }) async {
    if (connections.any(
      (c) => c.live && c.issuerSiteId == issuerSiteId && c.targetId == targetId,
    )) {
      throw StateError('this issuer is already connected to this target');
    }
    final c = AccountingConnection(
      id: 'demo-connection-${_next++}',
      issuerSiteId: issuerSiteId,
      targetId: targetId,
      authKind: AccountingAuthKind.token,
      status: ConnectionStatus.pending,
      displayName: displayName,
    );
    connections.add(c);
    return c;
  }

  @override
  Future<AccountingConnection> setToken(
    String connectionId, {
    required String token,
    required String remoteTenantId,
  }) async {
    final c = connections[_index(connectionId)];
    if (!c.live) throw StateError('this connection was revoked');
    return _replace(
      c,
      status: ConnectionStatus.connected,
      remoteTenantId: remoteTenantId.isEmpty ? null : remoteTenantId,
      secretsSet: const ['access_token'],
    );
  }

  @override
  Future<SignInStart> startSignIn(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
    String? connectionId,
  }) async => const SignInNotConfigured();

  @override
  Future<void> refresh(String connectionId) async {
    _index(connectionId);
  }

  @override
  Future<AccountingConnection> revoke(String connectionId) async {
    final c = connections[_index(connectionId)];
    if (!c.live) return c;
    return _replace(
      c,
      status: ConnectionStatus.revoked,
      secretsSet: const [],
      revokedAt: today,
    );
  }

  @override
  Future<AccountingConnection> saveMap(
    String connectionId,
    AccountingMapDraft draft,
  ) async {
    final c = connections[_index(connectionId)];
    if (!c.live) throw StateError('this connection was revoked');
    if (!accountingMapKeyValid(draft.kind, draft.key)) {
      throw StateError('not a ${draft.kind.wire} key');
    }
    final kept = [
      for (final m in c.maps)
        if (m.kind != draft.kind || m.key != draft.key) m,
    ];
    return _replace(
      c,
      maps: [
        ...kept,
        AccountingMap(
          id: 'demo-map-${_next++}',
          kind: draft.kind,
          key: draft.key,
          remoteId: draft.remoteId,
          remoteCode: draft.remoteCode,
          remoteName: draft.remoteName,
        ),
      ]..sort((a, b) => '${a.kind.index}${a.key}'.compareTo('${b.kind.index}${b.key}')),
    );
  }

  @override
  Future<AccountingConnection> deleteMap(String mapId) async {
    final c = connections.firstWhere((c) => c.maps.any((m) => m.id == mapId));
    return _replace(c, maps: [
      for (final m in c.maps)
        if (m.id != mapId) m,
    ]);
  }

  bool _overlaps(DateTime aFrom, DateTime aTo, DateTime from, DateTime to) =>
      !aFrom.isAfter(to) && !aTo.isBefore(from);

  @override
  Future<AccountingTransfers> fetchTransfers(
    String workspaceId,
    DateTime from,
    DateTime to,
  ) async {
    if (to.isBefore(from)) throw StateError('the period ends before it starts');
    final overview = await books.fetch(workspaceId);
    return AccountingTransfers(
      files: [
        for (final e in overview.exports)
          if (_overlaps(e.from, e.to, from, to))
            TransferFile(
              id: e.id,
              formatId: e.formatId,
              from: e.from,
              to: e.to,
              sha256: e.sha256,
              documentCount: e.documentCount,
              closedPeriod: e.closedPeriod,
              exportedAt: e.exportedAt,
              deliveries: [
                for (final d in deliveries)
                  if (d.bookExportId == e.id) d,
              ],
            ),
      ],
      deliveries: [
        for (final d in deliveries)
          if (d.connectionId != null &&
              _overlaps(d.eventDate, d.eventDate, from, to))
            d,
      ],
    );
  }

  @override
  Future<FileDeliveryOutcome> recordFileDeliveries(
    String workspaceId, {
    required String targetId,
    required String issuerSiteId,
    required String bookExportId,
    required List<FileDocument> documents,
  }) async {
    final BookExport export = (await books.fetch(workspaceId)).exports
        .firstWhere((e) => e.id == bookExportId);
    var created = 0;
    var unchanged = 0;
    var changed = 0;
    for (final doc in documents) {
      final i = deliveries.indexWhere(
        (d) =>
            d.connectionId == null &&
            d.targetId == targetId &&
            d.documentKind == doc.kind &&
            d.documentId == doc.id &&
            d.eventDate == doc.date,
      );
      final row = AccountingDelivery(
        id: i < 0 ? 'demo-delivery-${_next++}' : deliveries[i].id,
        targetId: targetId,
        bookExportId: export.id,
        documentKind: doc.kind,
        documentId: doc.id,
        documentNumber: doc.number,
        eventDate: doc.date,
        payloadSha256: doc.sha256,
        status: DeliveryStatus.generated,
        attempts: i < 0 ? 1 : deliveries[i].attempts + 1,
        recordedAt: today,
      );
      if (i < 0) {
        deliveries.add(row);
        created++;
      } else if (deliveries[i].payloadSha256 == doc.sha256) {
        unchanged++;
      } else {
        deliveries[i] = row;
        changed++;
      }
    }
    return FileDeliveryOutcome(
      created: created,
      unchanged: unchanged,
      changed: changed,
    );
  }
}
