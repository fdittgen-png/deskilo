// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

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
  factory WorkspaceApplication.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'workspace_application');
    return WorkspaceApplication(
      id: r.string('id'),
      workspaceName: r.string('workspace_name'),
      applicantName: r.stringOr('applicant_name'),
      status: r.string('status'),
      createdAt: r.dateTime('created_at'),
      isApplicant: r.boolOr('is_applicant', false),
    );
  }
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
  factory ApplicationMessage.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'application_message');
    return ApplicationMessage(
      id: r.string('id'),
      authorName: r.stringOr('author_name'),
      kind: r.string('kind'),
      body: r.string('body'),
      createdAt: r.dateTime('created_at'),
      isMine: r.boolOr('is_mine', false),
    );
  }
}

abstract interface class WorkspaceApplicationRepository {
  Future<List<WorkspaceApplication>> list({ApplicationCursor? before});
  Future<List<ApplicationMessage>> thread(
    String id, {
    ApplicationCursor? before,
  });
  Future<void> send(String id, String body, {required String expectedAccount});
}
