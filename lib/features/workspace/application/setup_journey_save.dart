// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/setup_journey.dart';
import '../domain/setup_levels.dart';
import '../providers/local_setup_providers.dart';

/// #2868 — remembers the [answers] and the [levels] the owner applied, as
/// one write against the journey version the screen read
/// ([expectedVersion], null when none was saved). Throws
/// `SetupJourneyConflict` when another configurer saved meanwhile; the
/// journey is read again either way, so the screen shows what is stored.
Future<void> saveSetupJourney(
  WidgetRef ref, {
  required String workspaceId,
  required SetupAnswers answers,
  required SetupLevelVector levels,
  required int? expectedVersion,
}) async {
  try {
    await ref
        .read(localSetupRepositoryProvider)
        .saveSetupJourney(
          workspaceId,
          answers: answers,
          levels: levels,
          expectedVersion: expectedVersion,
          requestId: newRequestId(),
        );
  } finally {
    ref.invalidate(setupJourneyProvider(workspaceId));
  }
}

/// #2868 — the workspace import keeps the `<profile>` of a file
/// web/setup.html wrote as the workspace's journey: one save against the
/// version read just before. A file without a profile leaves the journey
/// as it is. Answers someone else saved in between are kept, not
/// overwritten: the import's features are applied either way.
Future<void> saveImportedSetupProfile(
  WidgetRef ref, {
  required String workspaceId,
  required String xml,
}) async {
  final profile = SetupProfile.fromWorkspaceXml(xml);
  if (profile == null) return;
  final read = await ref
      .read(localSetupRepositoryProvider)
      .setupJourney(workspaceId);
  try {
    await saveSetupJourney(
      ref,
      workspaceId: workspaceId,
      answers: profile.answers,
      levels: profile.levels,
      expectedVersion: read?.version,
    );
  } on SetupJourneyConflict catch (e, st) {
    TraceLogger.instance.warn(
      'workspace',
      'imported setup profile not kept: answers saved meanwhile',
      error: e,
      stackTrace: st,
    );
  }
}
