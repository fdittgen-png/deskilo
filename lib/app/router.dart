// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/schema_version.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/kiosk/providers/kiosk_mode.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/task_recorder/presentation/ui_capture.dart'
    show RecorderWindowObserver;
import '../features/workspace/providers/workspace_providers.dart';
import 'entry_intents.dart';
import 'entry_resumption.dart';
import 'page_routes.dart';
import 'route_env.dart';
import 'route_redirect.dart';
import 'routes/auth_routes.dart';
import 'routes/directory_routes.dart';
import 'routes/editor_routes.dart';
import 'routes/events_routes.dart';
import 'routes/help_routes.dart';
import 'routes/kiosk_routes.dart';
import 'routes/mcp_routes.dart';
import 'routes/me_routes.dart';
import 'routes/members_routes.dart';
import 'routes/money_routes.dart';
import 'routes/plan_routes.dart';
import 'routes/profile_routes.dart';
import 'routes/reservations_routes.dart';
import 'routes/task_recorder_routes.dart';
import 'routes/workspace_routes.dart';
import 'shell/shell_routes.dart';

export 'shell/shell_destinations.dart' show ShellBranch;

part 'router.g.dart';

// #1306 — ShellBranch lives beside the one destination list that uses it.

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  late final GoRouter router;
  // #1650 — a refresh re-asks the redirect about where the person IS
  // (entry_resumption.dart says why the reported location is not that).
  void reask() => reaskRedirect(router);

  ref
    ..listen(authStateProvider, (_, _) => reask())
    ..listen(myWorkspacesProvider, (_, _) => reask())
    // Feature flags follow the ACTIVE workspace (#146): switching
    // profiles must re-evaluate the redirects even when the workspace
    // list itself did not change.
    ..listen(enabledFeaturesProvider, (_, _) => reask())
    // Kiosk lock (0043): the active membership decides whether the app is
    // a wall tablet — re-evaluate when it resolves or changes.
    ..listen(myMemberProvider, (_, _) => reask())
    ..listen(activeWorkspaceIdProvider, (_, _) => reask()) // #1823
    // Kiosk gate: the accept/reject decision moves the pad between the
    // gate, the locked kiosk view, and the normal app.
    ..listen(kioskModeProvider, (_, _) => reask())
    // #751 — the consent gate reads the profile's accepted policy version:
    // re-evaluate when the profile resolves, and after an acceptance.
    ..listen(myProfileProvider, (_, _) => reask())
    ..listen(requiredPrivacyVersionProvider, (_, _) => reask()) // #1914
    ..listen(schemaCompatibilityProvider, (_, _) => reask()) // #1312
    // #1650 — the continuation restored from the device, or captured on
    // the way to sign-in: its destination is where sign-in returns to.
    ..listen(entryIntentsProvider, (_, _) => reask());

  final env = RouteEnv(ref);
  router = GoRouter(
    // The Reserve hub is the app's home (the centre button's form): it
    // is what opens on start, after sign-in and after onboarding.
    initialLocation: '/reserve',
    // #2142 — tells a live task recording that a window opened or
    // closed; does nothing while none is live.
    observers: [RecorderWindowObserver()],
    // #1650 — the rules live in route_policy.dart as a pure function over
    // facts; this closure only collects the facts and asks. Building them
    // reads; nothing here writes.
    redirect: (context, state) => appRedirect(env, state),
    routes: [
      ...authRoutes(env),
      for (final page in openedPages) page.route(), // #2388
      ...meRoutes(env),
      ...kioskRoutes(env),
      ...workspaceRoutes(env),
      shellRoute(env),
      ...profileRoutes(env),
      ...helpRoutes(env),
      ...eventsRoutes(env),
      ...reservationsRoutes(env),
      ...planRoutes(env),
      ...directoryRoutes(env),
      ...membersRoutes(env),
      ...editorRoutes(env),
      ...mcpRoutes(env),
      ...taskRecorderRoutes(env),
      ...moneyRoutes(env),
    ],
  );
  ref.onDispose(router.dispose);
  // #1650 — the continuation is spent where the person arrives.
  void arrived() => spendOnArrival(router, ref);
  router.routerDelegate.addListener(arrived);
  ref.onDispose(() => router.routerDelegate.removeListener(arrived));
  return router;
}
