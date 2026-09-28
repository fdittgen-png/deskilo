// SPDX-License-Identifier: AGPL-3.0-or-later
/// Source captured from the authenticated client that reads the templates.
/// The account is an in-memory guard only, never workbook content.
class WorkbookOrigin {
  const WorkbookOrigin({required this.sourceId, required this.installationId,
    required this.accountId, this.sessionId = ''});
  final String sourceId;
  final String installationId;
  final String accountId;
  final String sessionId;

  bool sameContext(WorkbookOrigin other) => sourceId == other.sourceId &&
      installationId == other.installationId && accountId == other.accountId &&
      sessionId == other.sessionId;
  String scopedTemplate(String id) => '$sourceId:$installationId:$id';
}

abstract interface class WorkbookOriginRepository {
  Future<WorkbookOrigin> read();
}
