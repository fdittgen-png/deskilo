// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — what a recording says when the person navigates to a screen.
//
// Three answers, decided from the route PATH alone (never its query, its
// ids or anything on the screen), by the coverage manifest:
//   * an instrumented surface: say nothing here, its own seams speak;
//   * a protected surface: one "excluded step" marker with its category,
//     and nothing of its contents, ever;
//   * anything else: a visible "the recorder cannot describe this" step,
//     so an uninstrumented screen never passes for covered.

import '../domain/coverage_manifest.dart';
import '../domain/action_registry.dart';

/// How the recorder treats a route.
sealed class RouteTreatment {
  const RouteTreatment();
}

/// Recorded by the screen's own seams, or the recorder itself.
final class Instrumented extends RouteTreatment {
  const Instrumented();
}

/// Contents never recorded; one marker of [category].
final class Protected extends RouteTreatment {
  const Protected(this.category);
  final ProtectedSurface category;
}

/// Not instrumented: a visible manual step.
final class Unrecorded extends RouteTreatment {
  const Unrecorded();
}

/// The recorder's own screen.
const String taskRecorderRoute = '/task-recorder';

/// #1872 — the local task workbench.
const String taskWorkbenchRoute = '/task-workbench';

/// How the recorder treats the route at [path], from the coverage
/// manifest (domain/coverage_manifest.dart). A path no row matches is
/// a manual step: never silently covered.
RouteTreatment treatRoute(String path) {
  for (final row in routeCoverage) {
    if (!row.matches(path)) continue;
    return switch (row.status) {
      CoverageStatus.recorded ||
      CoverageStatus.recorder => const Instrumented(),
      CoverageStatus.excluded => Protected(row.category!),
      CoverageStatus.planned => const Unrecorded(),
    };
  }
  return const Unrecorded();
}
