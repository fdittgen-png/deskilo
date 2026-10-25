// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the writes and the one read the settings screen's backup tools
// ask for: the configuration section of the XML backup (#916), the
// restore (#165) and the reset (0039). The screen says what the owner
// asked for; these resolve the repositories.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/server_error.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/workspace_import.dart';
import '../domain/workspace_xml.dart';
import '../providers/workspace_import_providers.dart';
import '../providers/workspace_providers.dart';

/// The configuration tree of [workspaceId] the XML backup carries.
Future<Map<String, Object?>> exportWorkspaceConfiguration(
        WidgetRef ref, String workspaceId) =>
    ref.read(workspaceImportRepositoryProvider).exportConfiguration(workspaceId);

/// Applies an imported configuration tree; never refused over
/// reservations.
Future<void> importWorkspaceConfiguration(WidgetRef ref, String workspaceId,
        Map<String, Object?> configuration) =>
    ref
        .read(workspaceImportRepositoryProvider)
        .importConfiguration(workspaceId, configuration);

/// Replaces the floor plan with the imported one. The server refuses it
/// while the space has reservations; with [keepOnReservations] (a
/// configuration already applied) that refusal keeps the plan and
/// answers true — "plan kept", not a failure. Any other failure throws.
Future<bool> importWorkspaceFloorPlan(
  WidgetRef ref,
  String workspaceId,
  WorkspaceXmlData data, {
  required bool keepOnReservations,
}) async {
  try {
    await ref
        .read(workspaceImportRepositoryProvider)
        .importFloorPlan(workspaceId, data);
    return false;
  } on Object catch (e, st) {
    final message = serverErrorMessage(e);
    if (!keepOnReservations ||
        message == null ||
        !message.contains(kWorkspaceHasReservationsError)) {
      rethrow;
    }
    TraceLogger.instance.warn(
        'workspace', 'workspace XML import: plan kept (reservations)',
        error: e, stackTrace: st);
    return true;
  }
}

/// Wipes every transaction and the floor plan, keeping settings and
/// members (0039).
Future<void> resetWorkspaceData(WidgetRef ref, String workspaceId) =>
    ref.read(workspaceRepositoryProvider).resetWorkspace(workspaceId);
