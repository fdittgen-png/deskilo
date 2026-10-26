// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one door for the accounting connections, their mappings and the log
// of what a file carried. The server decides who may (manageBilling to
// connect and map, exportData to log, the accountingConnectors flag for
// all) and holds every secret; this refuses only what cannot be right, so
// a form names the field before anything is sent.
import '../../../core/trace/trace_logger.dart';
import '../domain/accounting_connection.dart';
import '../domain/generic_journal_csv.dart';
import '../domain/posting.dart';


/// Why a mapping cannot be saved as typed.
enum MapDraftProblem { key, remote }

/// The problem of [draft], or null when it can be sent.
MapDraftProblem? mapDraftProblem(AccountingMapDraft draft) {
  if (!accountingMapKeyValid(draft.kind, draft.key.trim())) {
    return MapDraftProblem.key;
  }
  if (draft.remoteId.trim().isEmpty && draft.remoteCode.trim().isEmpty) {
    return MapDraftProblem.remote;
  }
  return null;
}

/// Whether [token] has a length the server keeps; it says so first, so a
/// form names the field before anything is sent.
bool _tokenFits(String token) {
  final n = token.trim().length;
  return n >= accountingTokenLength.min && n <= accountingTokenLength.max;
}

class AccountingConnectionCommands {
  const AccountingConnectionCommands(this._repository);

  final AccountingConnectionRepository _repository;

  /// Opens a connection to [targetId] for [issuerSiteId] reached with
  /// [token]; null when the token is too short (nothing is sent).
  Future<AccountingConnection?> connectWithToken(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
    required String token,
    required String remoteTenantId,
  }) async {
    if (!_tokenFits(token)) return null;
    final opened = await _repository.openTokenConnection(
      workspaceId,
      issuerSiteId: issuerSiteId,
      targetId: targetId,
      displayName: displayName.trim(),
    );
    return _repository.setToken(
      opened.id,
      token: token.trim(),
      remoteTenantId: remoteTenantId.trim(),
    );
  }

  /// Replaces the token of an existing token connection; null when the
  /// token does not fit, or the connection delivered (its company stays:
  /// another one is a new connection).
  Future<AccountingConnection?> replaceToken(
    AccountingConnection connection, {
    required String token,
  }) async {
    if (!_tokenFits(token) || connection.delivered) return null;
    return _repository.setToken(
      connection.id,
      token: token.trim(),
      remoteTenantId: connection.remoteTenantId,
    );
  }

  Future<SignInStart> startSignIn(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
    String? connectionId,
  }) => _repository.startSignIn(
    workspaceId,
    issuerSiteId: issuerSiteId,
    targetId: targetId,
    displayName: displayName.trim(),
    connectionId: connectionId,
  );

  Future<void> refresh(String connectionId) =>
      _repository.refresh(connectionId);

  Future<AccountingConnection> revoke(String connectionId) =>
      _repository.revoke(connectionId);

  /// Saves [draft]; null when [mapDraftProblem] names a problem.
  Future<AccountingConnection?> saveMap(
    String connectionId,
    AccountingMapDraft draft,
  ) async {
    if (mapDraftProblem(draft) != null) return null;
    return _repository.saveMap(
      connectionId,
      AccountingMapDraft(
        kind: draft.kind,
        key: draft.key.trim(),
        remoteId: draft.remoteId.trim(),
        remoteCode: draft.remoteCode.trim(),
        remoteName: draft.remoteName.trim(),
      ),
    );
  }

  Future<AccountingConnection> deleteMap(String mapId) =>
      _repository.deleteMap(mapId);

  /// Records the documents the generic journal of [postings] carried in
  /// the logged file [bookExportId], one delivery each, for the issuer
  /// that keeps the book. The file is the accountant's already: a failed
  /// record is traced and never turns the export into a failure.
  Future<FileDeliveryOutcome?> logJournalFile(
    String workspaceId, {
    required String bookExportId,
    required String targetId,
    required String issuerSiteId,
    required List<Posting> postings,
  }) async {
    try {
      return await _repository.recordFileDeliveries(
        workspaceId,
        targetId: targetId,
        issuerSiteId: issuerSiteId,
        bookExportId: bookExportId,
        documents: genericJournalDocuments(postings),
      );
    } on Exception catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'the documents of the accounting file were not logged',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
