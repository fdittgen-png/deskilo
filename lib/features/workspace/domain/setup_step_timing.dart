// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How long a setup step takes, as the instance observed it (9999). A
// session is the time from opening a step's page to the step turning
// ready. The server keeps each one without a person — no user, no name,
// the workspace only as the key that makes a repeat harmless — aggregates
// them over the whole instance and answers a range per step, the median to
// the 80th percentile, only from five sessions on. Nothing leaves the
// instance; below five the guide widens the catalogue's figure instead.
import '../../../core/data/json_reader.dart';
import 'setup_status.dart';

/// One finished session on a step, as the app reports it.
class SetupStepObservation {
  const SetupStepObservation({
    required this.workspaceId,
    required this.step,
    required this.openedAt,
    required this.duration,
  });

  final String workspaceId;
  final String step;

  /// When the step's page was opened; with the workspace and the step,
  /// what makes reporting the same session twice harmless.
  final DateTime openedAt;

  /// From [openedAt] to the step turning ready.
  final Duration duration;
}

/// The server's observed ranges (`setup_step_timing_ranges`), by step id,
/// in minutes. A row that is not a range is left out.
Map<String, SetupEstimate> setupTimingRangesFromJson(Object? json) {
  final ranges = <String, SetupEstimate>{};
  for (final raw in json is List ? json : const []) {
    if (raw is! Map) continue;
    final r = JsonReader.of(raw, context: 'setup step timing range');
    final step = r.stringOr('step');
    final low = r.intOrNull('low_minutes');
    final high = r.intOrNull('high_minutes');
    if (step.isEmpty || low == null || high == null || low < 1 || high <= low) {
      continue;
    }
    ranges[step] = (low: low, high: high);
  }
  return ranges;
}
