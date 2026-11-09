// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of WorkspaceTemplates: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/template_publication.dart';
import 'package:deskilo/features/workspace/domain/template_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';

import 'fake_workspace_state.dart';

mixin FakeWorkspaceTemplates on FakeWorkspaceState
    implements TemplateRepository {
  @override
  Future<List<WorkspaceTemplate>> fetchWorkspaceTemplates() async =>
      List.of(templates);
  // #1656 next apply's report

  @override
  Future<TemplateApplyResult> applyWorkspaceTemplate(
    String workspaceId,
    String templateId, {
    List<String>? groups,
    int? expectedVersion,
    String? requestId,
  }) async {
    if (!templates.any((t) => t.id == templateId)) {
      throw Exception('unknown template');
    }
    appliedTemplates.add((
      workspaceId: workspaceId,
      templateId: templateId,
      groups: groups,
    ));
    return templateApplyResult;
  }

  @override
  Future<TemplatePublication> templatePublicationPreview(
    String workspaceId, {
    List<String>? groups,
  }) async {
    if (groups == null) return publication;
    return TemplatePublication(
      published: [
        for (final p in publication.published)
          if (groups.contains(p.group.wire)) p,
      ],
      neverPublished: publication.neverPublished,
      planNames: groups.contains('space') ? publication.planNames : const [],
    );
  }

  @override
  Future<TemplatePreview> previewWorkspaceTemplate(
    String workspaceId,
    String templateId, {
    List<String>? groups,
  }) async {
    final set = templatePreviews[templateId];
    if (set != null) return set;
    final t = templates.firstWhere(
      (x) => x.id == templateId,
      orElse: () => throw Exception('unknown template'),
    );
    return TemplatePreview(
      compatibility: TemplateCompatibility.supported,
      groups: [
        if (t.entities.contains('floor_plan'))
          TemplateGroupPreview(
            group: TemplateGroup.space,
            wire: 'space',
            state: TemplateGroupState.isNew,
            itemCount: t.counts.seats + t.counts.desks + t.counts.levels,
          ),
      ],
    );
  }

  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(String templateId) async {
    final set = templateInspections[templateId];
    if (set != null) return set;
    final t = templates.firstWhere(
      (x) => x.id == templateId,
      orElse: () => throw Exception('unknown template'),
    );
    // A seeded outline refusal (#1303 tests) refuses here too.
    final outline = await workspaceTemplateOutline(templateId);
    return TemplateInspection(
      templateId: t.id,
      key: t.key,
      name: t.name,
      entities: t.entities,
      status: TemplateInspectionStatus.ok,
      profile: t.carriesConfiguration
          ? TemplateProfile.partial
          : TemplateProfile.legacy,
      compatibility: outline.compatibility,
      outline: outline,
    );
  }

  @override
  Future<TemplateOutline> workspaceTemplateOutline(String templateId) async {
    final set = templateOutlines[templateId];
    if (set != null) return set;
    final t = templates.firstWhere(
      (x) => x.id == templateId,
      orElse: () => throw Exception('unknown template'),
    );
    return TemplateOutline(
      compatibility: TemplateCompatibility.supported,
      groups: [if (t.entities.contains('floor_plan')) TemplateGroup.space],
    );
  }

  @override
  Future<String> saveWorkspaceAsTemplate(
    String workspaceId, {
    required String key,
    required String name,
    String description = '',
    TemplateVisibility visibility = TemplateVisibility.private,
    List<String> tags = const [],
    List<String>? groups,
    String? requestId,
  }) async {
    // #1658 — the same request again is a retry, not a second publication.
    final args = '$key|$name|$description|${visibility.name}|$tags|$groups';
    if (requestId != null) {
      final prior = publishRequests[requestId];
      if (prior != null) {
        if (prior.args != args) throw const TemplatePublishConflict();
        return prior.id;
      }
    }
    savedTemplateGroups.add(groups);
    if (visibility == TemplateVisibility.builtin) {
      throw Exception('a workspace cannot publish a builtin template');
    }
    templates.removeWhere(
      (t) => t.ownerWorkspaceId == workspaceId && t.key == key,
    );
    final id = 'tpl-$key';
    templates.add(
      WorkspaceTemplate(
        id: id,
        key: key,
        name: name,
        description: description,
        visibility: visibility,
        ownerWorkspaceId: workspaceId,
        tags: tags,
        floorPlan: const <Object?>[
          <String, Object?>{'name': 'Snapshot', 'offices': <Object?>[]},
        ],
      ),
    );
    if (requestId != null) publishRequests[requestId] = (args: args, id: id);
    if (loseNextPublishResponse) {
      loseNextPublishResponse = false;
      throw Exception('ClientException: Connection reset');
    }
    return id;
  }

  @override
  Future<void> setWorkspaceTemplateVisibility(
    String templateId,
    TemplateVisibility visibility,
  ) async {
    final i = templates.indexWhere((t) => t.id == templateId);
    if (i < 0) throw Exception('unknown template');
    final t = templates[i];
    templates[i] = WorkspaceTemplate(
      id: t.id,
      key: t.key,
      name: t.name,
      description: t.description,
      visibility: visibility,
      ownerWorkspaceId: t.ownerWorkspaceId,
      floorPlan: t.floorPlan,
    );
  }

  @override
  Future<void> deleteWorkspaceTemplate(String templateId) async {
    templates.removeWhere((t) => t.id == templateId);
    templateGrants.remove(templateId);
  }

  @override
  Future<void> grantWorkspaceTemplate(String templateId, String email) async {
    final list = templateGrants.putIfAbsent(templateId, () => []);
    final e = email.trim().toLowerCase();
    if (!list.contains(e)) list.add(e);
  }

  @override
  Future<void> revokeWorkspaceTemplateGrant(
    String templateId,
    String email,
  ) async {
    templateGrants[templateId]?.remove(email.trim().toLowerCase());
  }

  @override
  Future<List<String>> workspaceTemplateGrantees(String templateId) async =>
      List.of(templateGrants[templateId] ?? const []);
}
