// SPDX-License-Identifier: AGPL-3.0-or-later
import 'template_inspection.dart';
import 'template_outline.dart';
import 'template_preview.dart';
import 'template_publication.dart';
import 'workspace_template.dart';

/// Workspace templates: browse, apply, publish, share.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class TemplateRepository {
  /// Every template this member may read: builtin, public, the ones
  /// their workspaces own, and the ones shared with their address. The
  /// server decides; this is what it returned.
  Future<List<WorkspaceTemplate>> fetchWorkspaceTemplates();

  /// Merges what [templateId] carries into [workspaceId], never wiping
  /// (#1276); [groups] narrows it, null applies all. `manageConfiguration`;
  /// refused for an unreadable template or an unknown snapshot format.
  Future<TemplateApplyResult> applyWorkspaceTemplate(
    String workspaceId,
    String templateId, {
    List<String>? groups,
    int? expectedVersion,
    String? requestId,
  });

  /// #1280 — per group, what applying [templateId] here would change.
  Future<TemplatePreview> previewWorkspaceTemplate(
    String workspaceId,
    String templateId, {
    List<String>? groups,
  });

  /// #1303 — what [templateId] sets up, asked before any workspace exists.
  Future<TemplateOutline> workspaceTemplateOutline(String templateId);

  /// #1655 — every field [templateId] carries, with its disposition, as
  /// `inspect_workspace_template` (0266) walked it: the outline the
  /// confirm step reads, plus the problems that reject it, the inputs the
  /// target must supply, the exclusions and a digest. Readable by whoever
  /// may read the template; it writes nothing.
  Future<TemplateInspection> inspectWorkspaceTemplate(String templateId);

  /// Snapshots [workspaceId] through `template_publication_rules` (#1276);
  /// the same key again updates in place and bumps the version.
  ///
  /// #1658 — with [requestId] (0286) a retry of the same request returns
  /// the template it already published instead of publishing again, and
  /// the same id with other arguments throws [TemplatePublishConflict].
  Future<String> saveWorkspaceAsTemplate(
    String workspaceId, {
    required String key,
    required String name,
    String description = '',
    TemplateVisibility visibility = TemplateVisibility.private,
    List<String> tags = const [],
    List<String>? groups,
    String? requestId,
  });

  /// #1280 — what publishing [workspaceId] with [groups] would carry.
  Future<TemplatePublication> templatePublicationPreview(
    String workspaceId, {
    List<String>? groups,
  });

  Future<void> setWorkspaceTemplateVisibility(
    String templateId,
    TemplateVisibility visibility,
  );

  Future<void> deleteWorkspaceTemplate(String templateId);

  /// Invites an address to a template. By address, not by account, so
  /// the call answers nothing about who has an account (#1120).
  Future<void> grantWorkspaceTemplate(String templateId, String email);

  Future<void> revokeWorkspaceTemplateGrant(String templateId, String email);

  Future<List<String>> workspaceTemplateGrantees(String templateId);
}
