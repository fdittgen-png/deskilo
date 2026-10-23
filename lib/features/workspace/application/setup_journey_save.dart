// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/request_id.dart';
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
