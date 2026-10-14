// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the task wizard, the recorder and the workbench.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/task_recorder/presentation/route_classification.dart'
    show taskRecorderRoute, taskWizardRoute, taskWorkbenchRoute;
import '../../features/task_recorder/presentation/screens/task_recorder_screen.dart';
import '../../features/task_recorder/presentation/screens/task_wizard_screen.dart';
import '../../features/task_recorder/presentation/screens/task_workbench_screen.dart';
import '../route_env.dart';

/// Routes of the taskRecorder feature.
List<RouteBase> taskRecorderRoutes(RouteEnv env) {
  return [
    // The task wizard: guides, recordings and tools, one screen.
    GoRoute(
      path: taskWizardRoute,
      builder: (context, state) => const TaskWizardScreen(),
    ),
    // #1865 — this account's own recordings on this device. Account-
    // level: reading, exporting and deleting them never needs a flag;
    // Start is gated by taskRecorder inside the screen.
    GoRoute(
      path: taskRecorderRoute,
      builder: (context, state) => const TaskRecorderScreen(),
    ),
    // #1872 — the local task workbench: no account, no workspace.
    GoRoute(
      path: taskWorkbenchRoute,
      builder: (context, state) => const TaskWorkbenchScreen(),
    ),
  ];
}
