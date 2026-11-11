// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3702 -- the levels the setup screen holds as a candidate: what the owner
// chose by hand, else the recommendation for the processes the answers name,
// else the level the business has; then checked against the levels' needs.
import 'setup_levels.dart';

/// The candidate vector and the levels kept up because another level needs
/// them ([holdRecomputedAtNeeds]).
({
  SetupLevelVector vector,
  Map<SetupProcess, ({SetupProcess by, String level})> held,
})
setupCandidate({
  required SetupLevelVector current,
  required Map<SetupProcess, SetupRecommendation> recommended,
  required Map<SetupProcess, String> chosen,
  required Set<String> touched,
  required bool answered,
}) {
  final recompute = setupProcessesNaming(touched);
  final candidate = {
    for (final p in SetupProcess.values)
      p:
          chosen[p] ??
          (answered && recompute.contains(p)
              ? recommended[p]!.level
              : current[p]!),
  };
  return holdRecomputedAtNeeds(candidate, {
    for (final p in recompute)
      if (chosen[p] == null && answered) p,
  });
}
