// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the floor-plan editor and its level canvas.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/editor/presentation/screens/editor_screen.dart';
import '../../features/editor/presentation/screens/level_canvas_screen.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the editor feature.
List<RouteBase> editorRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/editor',
      // #2137 — the owner, or whoever holds manageSites (0363).
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageSites,
          bypass: RoleBypass.owner,
        ),
      ),
      builder: (context, state) => const EditorScreen(),
      routes: [
        GoRoute(
          path: 'level/:levelId',
          builder: (context, state) =>
              LevelCanvasScreen(levelId: state.pathParameters['levelId']!),
        ),
      ],
    ),
  ];
}
