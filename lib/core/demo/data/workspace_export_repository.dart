// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — each workspace's own-data export in memory, for the suite and
// for Demo: one document per workspace, or the refusal a test sets for it.
import 'package:deskilo/features/me/domain/workspace_export.dart';

class FakeWorkspaceExportRepository implements WorkspaceExportRepository {
  FakeWorkspaceExportRepository({
    required this.document,
    Map<String, Exception>? failures,
  }) : failures = failures ?? {};

  /// The export `export_my_data` would answer for a workspace.
  final Map<String, Object?> Function(WorkspaceExportSource source) document;

  /// What a workspace answers instead, by its local id.
  final Map<String, Exception> failures;

  /// The workspaces asked, in order.
  final List<String> asked = [];

  @override
  Future<WorkspaceExport> export(WorkspaceExportSource source) async {
    asked.add(source.workspaceId);
    final failure = failures[source.workspaceId];
    if (failure != null) throw failure;
    return WorkspaceExport.decode(source, document(source));
  }
}
