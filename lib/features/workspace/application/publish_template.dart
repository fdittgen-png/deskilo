// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1280 S3 — publishing this workspace as a template (ADR 0024: the sheet
// says what was chosen; this decides the request and what it makes stale).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/template_publication.dart';
import '../domain/workspace_template.dart';
import '../providers/workspace_providers.dart';

/// What the whole allow-list would publish — the sheet narrows it by the
/// groups ticked, locally, since the server answered for all of them.
Future<TemplatePublication> publicationPreview(
        WidgetRef ref, String workspaceId) =>
    ref.read(workspaceRepositoryProvider).templatePublicationPreview(workspaceId);

/// Publishes [name] with the ticked [groups]; every group ticked is sent as
/// null, so a template publishes whatever the server allows today.
Future<void> publishTemplate(
  WidgetRef ref,
  String workspaceId, {
  required String name,
  required String description,
  required TemplateVisibility visibility,
  required List<String> tags,
  required List<String>? groups,
}) async {
  await ref.read(workspaceRepositoryProvider).saveWorkspaceAsTemplate(
        workspaceId,
        key: templateKeyFrom(name),
        name: name,
        description: description,
        visibility: visibility,
        tags: tags,
        groups: groups,
      );
  ref.invalidate(workspaceTemplatesProvider);
}
