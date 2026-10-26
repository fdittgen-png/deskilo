// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The accounting interface as the app reads it: an issuer's connection to
// an API target (its state, never a secret), the mappings a delivery reads
// on the other side, and the transfers of a period: every file handed out
// with the documents it carried, and every document delivered to a
// connection, with its digest and what the target answered. The server
// owns every rule (accounting_connections, accounting_maps,
// accounting_deliveries); this is what it answers.
//
// Pure Dart.
import '../../../core/data/json_reader.dart';
import 'accounting_delivery_run.dart';
import 'accounting_target.dart';

/// The right that connects, maps and revokes (the server's
/// `accounting_connector_actor`).
const String _accountingConnectPermission = 'manageBilling';

/// The rights that read the connections and the transfers (the server's
/// `accounting_reader`, beside the owner).
const Set<String> accountingTransferReaders = {
  'viewFinances',
  'exportData',
  _accountingConnectPermission,
};

/// What the accounting systems need of the space: its country (which
/// targets it is offered), its issuers by id, the rights the reader holds
/// (by name) and its members' names.
class AccountingSystemsScope {
  const AccountingSystemsScope({
    required this.countryCode,
    required this.issuers,
    required this.permissions,
    required this.memberNames,
  });

  final String countryCode;
  final Map<String, String> issuers;
  final Set<String> permissions;
  final Map<String, String> memberNames;

  bool get manage => permissions.contains(_accountingConnectPermission);
}

/// The state of a connection as the screen shows it.
enum ConnectionStatus {
  pending('pending'),
  connected('connected'),
  expired('expired'),
  revoked('revoked'),
  error('error');

  const ConnectionStatus(this.wire);
  final String wire;

  static ConnectionStatus of(String? wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => error);
}

/// What a mapping names on the target's side.
enum AccountingMapKind {
  /// A book role (`revenue:standard`) → a remote account.
  account('account'),

  /// A tax component key (`VAT|FR|taxed|20|2014`) → a remote tax code.
  tax('tax'),

  /// A member, site or supplier → a remote customer or vendor.
  party('party'),

  /// A revenue role → a remote item or product.
  item('item');

  const AccountingMapKind(this.wire);
  final String wire;

  static AccountingMapKind of(String? wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => account);
}

final _role = RegExp(r'^[a-z_]{1,40}(:[A-Za-z0-9_.-]{1,60})?$');
final _taxKey = RegExp(
  r'^[A-Z][A-Z0-9_]{0,15}\|[A-Z]{2}(-[A-Z0-9]{1,3})?\|'
  r'(taxed|zeroRated|exempt|outOfScope|reverseCharge)\|'
  r'[0-9]{1,3}(\.[0-9]{1,4})?\|[A-Za-z0-9_.:-]{0,60}$',
);
final _party = RegExp(
  r'^(member|site|supplier):[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
  r'[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Whether [key] is a key of [kind] as the server accepts it
/// (`accounting_map_key_valid`): checked before anything is sent, so the
/// form can name the field.
bool accountingMapKeyValid(AccountingMapKind kind, String key) =>
    switch (kind) {
      AccountingMapKind.account || AccountingMapKind.item => _role.hasMatch(key),
      AccountingMapKind.tax => _taxKey.hasMatch(key),
      AccountingMapKind.party => _party.hasMatch(key),
    };

/// The key of the party mapping of the member [memberId].
String memberMapKey(String memberId) => 'member:$memberId';

/// The shortest and the longest API token the server keeps
/// (`set_accounting_token_v1`); accounting_connection_test pins the pair to
/// the migration.
const ({int min, int max}) accountingTokenLength = (min: 8, max: 4000);

class AccountingMap {
  const AccountingMap({
    required this.id,
    required this.kind,
    required this.key,
    this.remoteId = '',
    this.remoteCode = '',
    this.remoteName = '',
  });

  factory AccountingMap.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'accounting map');
    return AccountingMap(
      id: r.string('id'),
      kind: AccountingMapKind.of(r.stringOrNull('kind')),
      key: r.string('key'),
      remoteId: r.stringOr('remote_id'),
      remoteCode: r.stringOr('remote_code'),
      remoteName: r.stringOr('remote_name'),
    );
  }

  final String id;
  final AccountingMapKind kind;
  final String key;
  final String remoteId;
  final String remoteCode;
  final String remoteName;

  /// What the target calls it: its code, else its id.
  String get remote => remoteCode.isNotEmpty ? remoteCode : remoteId;
}

/// A mapping as the form saves it.
class AccountingMapDraft {
  const AccountingMapDraft({
    required this.kind,
    required this.key,
    this.remoteId = '',
    this.remoteCode = '',
    this.remoteName = '',
  });

  final AccountingMapKind kind;
  final String key;
  final String remoteId;
  final String remoteCode;
  final String remoteName;
}

class AccountingConnection {
  const AccountingConnection({
    required this.id,
    required this.issuerSiteId,
    required this.targetId,
    required this.authKind,
    required this.status,
    this.remoteTenantId = '',
    this.displayName = '',
    this.statusDetail = '',
    this.connectedAt,
    this.revokedAt,
    this.delivered = false,
    this.secretsSet = const [],
    this.maps = const [],
  });

  factory AccountingConnection.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'accounting connection');
    return AccountingConnection(
      id: r.string('id'),
      issuerSiteId: r.string('issuer_site_id'),
      targetId: r.string('target_id'),
      authKind: AccountingAuthKind.of(r.stringOrNull('auth_kind')),
      status: ConnectionStatus.of(r.stringOrNull('status')),
      remoteTenantId: r.stringOr('remote_tenant_id'),
      displayName: r.stringOr('display_name'),
      statusDetail: r.stringOr('status_detail'),
      connectedAt: r.dateTimeOrNull('connected_at'),
      delivered: r.boolOr('delivered', fallback: false),
      revokedAt: r.dateTimeOrNull('revoked_at'),
      secretsSet: r.strings('secrets_set'),
      maps: [for (final m in r.list('maps')) AccountingMap.fromJson(m)],
    );
  }

  final String id;
  final String issuerSiteId;
  final String targetId;
  final AccountingAuthKind authKind;
  final ConnectionStatus status;
  final String remoteTenantId;
  final String displayName;
  final String statusDetail;
  final DateTime? connectedAt;
  final DateTime? revokedAt;

  /// Whether a document was delivered through it: its token then stays,
  /// and another company is a new connection.
  final bool delivered;

  /// The names of the secrets the server holds, never their values.
  final List<String> secretsSet;
  final List<AccountingMap> maps;

  bool get live => revokedAt == null;

  /// Whether a person must act before anything can be delivered: signed out
  /// at the target, never finished, or refused.
  bool get needsAttention =>
      live && status != ConnectionStatus.connected;
}

enum DeliveryStatus {
  generated('generated'),
  sent('sent'),
  acknowledged('acknowledged'),
  conflict('conflict'),
  failed('failed');

  const DeliveryStatus(this.wire);
  final String wire;

  static DeliveryStatus of(String? wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => failed);
}

/// One document carried by a file or delivered to a connection.
class AccountingDelivery {
  const AccountingDelivery({
    required this.id,
    required this.targetId,
    required this.documentKind,
    required this.documentId,
    required this.eventDate,
    required this.payloadSha256,
    required this.status,
    this.connectionId,
    this.bookExportId,
    this.documentNumber = '',
    this.remoteId = '',
    this.remoteNumber = '',
    this.remoteState = '',
    this.error = '',
    this.attempts = 1,
  });

  factory AccountingDelivery.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'accounting delivery');
    return AccountingDelivery(
      id: r.string('id'),
      targetId: r.string('target_id'),
      connectionId: r.stringOrNull('connection_id'),
      bookExportId: r.stringOrNull('book_export_id'),
      documentKind: r.string('document_kind'),
      documentId: r.string('document_id'),
      documentNumber: r.stringOr('document_number'),
      eventDate: DateTime.parse(r.string('event_date')),
      payloadSha256: r.string('payload_sha256'),
      remoteId: r.stringOr('remote_id'),
      remoteNumber: r.stringOr('remote_number'),
      remoteState: r.stringOr('remote_state'),
      status: DeliveryStatus.of(r.stringOrNull('status')),
      error: r.stringOr('error'),
      attempts: r.intOrNull('attempts') ?? 1,
    );
  }

  final String id;
  final String targetId;
  final String? connectionId;
  final String? bookExportId;

  /// The document event (`invoice`, `receipt`, `write_off`, ...).
  final String documentKind;
  final String documentId;
  final String documentNumber;
  final DateTime eventDate;
  final String payloadSha256;
  final String remoteId;
  final String remoteNumber;

  /// `draft` or `posted` when the target says; a remote draft is not a
  /// posted document.
  final String remoteState;
  final DeliveryStatus status;
  final String error;
  final int attempts;
}

/// One file handed out, with the documents it carried.
class TransferFile {
  const TransferFile({
    required this.id,
    required this.formatId,
    required this.from,
    required this.to,
    required this.sha256,
    required this.documentCount,
    required this.closedPeriod,
    required this.exportedAt,
    this.exportedByMemberId,
    this.deliveries = const [],
  });

  factory TransferFile.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'transfer file');
    return TransferFile(
      id: r.string('id'),
      formatId: r.string('format_id'),
      from: DateTime.parse(r.string('period_from')),
      to: DateTime.parse(r.string('period_to')),
      sha256: r.string('sha256'),
      documentCount: r.integer('document_count'),
      closedPeriod: r.boolOr('closed_period', fallback: false),
      exportedAt: r.dateTime('exported_at'),
      exportedByMemberId: r.stringOrNull('exported_by_member_id'),
      deliveries: [
        for (final d in r.list('deliveries')) AccountingDelivery.fromJson(d),
      ],
    );
  }

  final String id;
  final String formatId;
  final DateTime from;
  final DateTime to;
  final String sha256;
  final int documentCount;
  final bool closedPeriod;
  final DateTime exportedAt;
  final String? exportedByMemberId;

  /// The documents this file is the delivery of: a document an earlier
  /// file carried with the same digest stays with that file.
  final List<AccountingDelivery> deliveries;
}

/// What moved in a period: the files and the connection deliveries.
class AccountingTransfers {
  const AccountingTransfers({this.files = const [], this.deliveries = const []});

  factory AccountingTransfers.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'accounting transfers');
    return AccountingTransfers(
      files: [for (final f in r.list('files')) TransferFile.fromJson(f)],
      deliveries: [
        for (final d in r.list('deliveries')) AccountingDelivery.fromJson(d),
      ],
    );
  }

  final List<TransferFile> files;
  final List<AccountingDelivery> deliveries;
}

/// One document a file carried, as the file delivery records it.
class FileDocument {
  const FileDocument({
    required this.kind,
    required this.id,
    required this.number,
    required this.date,
    required this.sha256,
  });

  final String kind;
  final String id;
  final String number;
  final DateTime date;
  final String sha256;
}

/// What a file delivery became, per document.
class FileDeliveryOutcome {
  const FileDeliveryOutcome({
    this.created = 0,
    this.unchanged = 0,
    this.changed = 0,
  });

  factory FileDeliveryOutcome.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'file deliveries');
    return FileDeliveryOutcome(
      created: r.integer('created'),
      unchanged: r.integer('unchanged'),
      changed: r.integer('changed'),
    );
  }

  final int created;
  final int unchanged;
  final int changed;
}

/// The server's answer to a sign-in request: the target's sign-in page, or
/// that this installation registered no application with the target.
sealed class SignInStart {
  const SignInStart();
}

final class SignInPage extends SignInStart {
  const SignInPage(this.url);
  final Uri url;
}

final class SignInNotConfigured extends SignInStart {
  const SignInNotConfigured();
}

/// The connections, mappings and transfers of one space; every write is an
/// RPC or the `accounting-connect` function, and no read returns a secret.
abstract class AccountingConnectionRepository {
  Future<List<AccountingConnection>> fetchConnections(String workspaceId);

  /// A pending connection reached with a pasted token.
  Future<AccountingConnection> openTokenConnection(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
  });

  Future<AccountingConnection> setToken(
    String connectionId, {
    required String token,
    required String remoteTenantId,
  });

  /// The target's sign-in page for a new connection, or for [connectionId]
  /// signing in again.
  Future<SignInStart> startSignIn(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
    String? connectionId,
  });

  /// Asks the target for fresh tokens; answers the connection's new state.
  Future<void> refresh(String connectionId);

  Future<AccountingConnection> revoke(String connectionId);

  Future<AccountingConnection> saveMap(
    String connectionId,
    AccountingMapDraft draft,
  );

  Future<AccountingConnection> deleteMap(String mapId);

  Future<AccountingTransfers> fetchTransfers(
    String workspaceId,
    DateTime from,
    DateTime to,
  );

  Future<FileDeliveryOutcome> recordFileDeliveries(
    String workspaceId, {
    required String targetId,
    required String issuerSiteId,
    required String bookExportId,
    required List<FileDocument> documents,
  });

  /// Delivers the postings of [from]..[to] (one calendar month) to the
  /// connection [connectionId], or only the document event [document] of
  /// it, delivered again.
  Future<DeliveryRun> deliver(
    String connectionId, {
    required DateTime from,
    required DateTime to,
    ({String kind, String id})? document,
  });
}
