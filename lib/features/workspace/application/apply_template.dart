// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1280 S2 — previewing and applying a template to the current workspace.
//
// ADR 0024: the sheet says what was chosen; this file decides what that
// means — which request, and which caches the result makes stale. A
// template can touch the plan, the hours, the prices, the roles and the
// feature profile, so the invalidation is broad on purpose: a screen left
// showing the configuration from before would contradict the result the
// sheet just announced.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plan/providers/floor_plan_providers.dart';
import '../domain/template_preview.dart';
import '../domain/workspace_template.dart';
import '../providers/workspace_providers.dart';

/// What applying [template] here would change, per group.
Future<TemplatePreview> previewTemplate(
    WidgetRef ref, String workspaceId, WorkspaceTemplate template) {
  return ref
      .read(workspaceRepositoryProvider)
      .previewWorkspaceTemplate(workspaceId, template.id);
}

/// Applies exactly the [groups] chosen, never the whole template in a
/// configured workspace.
///
/// #1656 — answers what happened to the template's floor-plan prices, so
/// the sheet can say they were left alone in another currency.
Future<TemplateApplyResult> applyTemplateGroups(WidgetRef ref,
    String workspaceId, WorkspaceTemplate template, Set<String> groups,
    {required String requestId}) async {
  final outcome = await ref.read(workspaceRepositoryProvider).applyWorkspaceTemplate(
      workspaceId, template.id,
      groups: groups.toList()..sort(),
      // #1658 — the revision the preview showed, and one request per review.
      expectedVersion: template.templateVersion,
      requestId: requestId);
  ref
    ..invalidate(levelsProvider)
    ..invalidate(myWorkspacesProvider)
    ..invalidate(workspaceTemplatesProvider);
  return outcome;
}
