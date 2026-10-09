// SPDX-License-Identifier: AGPL-3.0-or-later

import '../domain/action_registry.dart';
import '../domain/recording_reference.dart';
import 'task_guide.dart';

export '../domain/recording_reference.dart';

/// Explicit destinations win. Older guides still resolve from their screen
/// steps. Record-specific pages open their chooser; no object is guessed.
String? guideStepRoute(List<GuideStep> steps, GuideStep step) {
  if (step.destination case final destination?) return destination;
  final own = guideSurfaceRoutes[recorderRegistry.action(step.action)?.surface];
  if (own != null) return own;
  final holder = steps.indexWhere(
    (s) => s.id == step.id || s.recovery.any((r) => r.id == step.id),
  );
  if (holder < 0) return null;
  for (var i = holder; i >= 0; i--) {
    final s = steps[i];
    if (s.destination != null) return s.destination;
    if (s.action == RecorderActions.uiOpenScreen) {
      return guidePageForTarget(s.target);
    }
    final named =
        guideSurfaceRoutes[recorderRegistry.action(s.action)?.surface];
    if (named != null) return named;
  }
  return null;
}

/// Resolve legacy context once, before playback. A guide with even one
/// unlinked main or recovery step is an editable draft, never a live guide.
TaskGuide? linkedGuide(TaskGuide guide) {
  GuideStep? resolve(GuideStep step) {
    final page = guideStepRoute(guide.steps, step);
    if (page == null || !isGuideDestination(page)) return null;
    final recovery = <GuideStep>[];
    for (final child in step.recovery) {
      final resolved = resolve(child);
      if (resolved == null) return null;
      recovery.add(resolved);
    }
    return step.copyWith(destination: page, recovery: recovery);
  }

  final steps = <GuideStep>[];
  for (final step in guide.steps) {
    final resolved = resolve(step);
    if (resolved == null) return null;
    steps.add(resolved);
  }
  if (steps.isEmpty) return null;
  return TaskGuide(
    actionContractVersion: guide.actionContractVersion,
    title: guide.title,
    sourceDigest: guide.sourceDigest,
    steps: steps,
  );
}
