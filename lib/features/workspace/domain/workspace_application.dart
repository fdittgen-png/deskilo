// SPDX-License-Identifier: AGPL-3.0-or-later
/// A request is an account record, even when workspace admission was refused.
typedef ApplicationCursor = ({DateTime at, String id});

class WorkspaceApplication {
  const WorkspaceApplication({
    required this.id,
    required this.workspaceName,
    required this.applicantName,
    required this.status,
    required this.createdAt,
    required this.isApplicant,
  });
  final String id, workspaceName, applicantName, status;
  final DateTime createdAt;
  final bool isApplicant;
  ApplicationCursor get cursor => (at: createdAt, id: id);
  factory WorkspaceApplication.fromJson(Map<String, dynamic> json) =>
      WorkspaceApplication(
        id: json['id'] as String,
        workspaceName: json['workspace_name'] as String,
        applicantName: json['applicant_name'] as String? ?? '',
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isApplicant: json['is_applicant'] == true,
      );
}

class ApplicationMessage {
  const ApplicationMessage({
    required this.id,
    required this.authorName,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });
  final String id, authorName, kind, body;
  final DateTime createdAt;
  final bool isMine;
  ApplicationCursor get cursor => (at: createdAt, id: id);
  factory ApplicationMessage.fromJson(Map<String, dynamic> json) =>
      ApplicationMessage(
        id: json['id'] as String,
        authorName: json['author_name'] as String? ?? '',
        kind: json['kind'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isMine: json['is_mine'] == true,
      );
}

abstract interface class WorkspaceApplicationRepository {
  Future<List<WorkspaceApplication>> list({ApplicationCursor? before});
  Future<List<ApplicationMessage>> thread(
    String id, {
    ApplicationCursor? before,
  });
  Future<void> send(String id, String body, {required String expectedAccount});
}
