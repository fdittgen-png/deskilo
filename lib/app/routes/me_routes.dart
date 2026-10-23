// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the Me layer and public profiles.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
//
// Me is one StatefulShellRoute with five branches — Overview, My spaces,
// Discover, Messages, My data — each a route-owned destination with its own
// navigator, so a switch restores the branch's stack. The `personalShell`
// flag decides what the shell draws: on, the personal shell around the
// branches; off, the four-tab shell at `/me` exactly as before, and every
// other personal-shell address leads to the legacy screen that holds the
// same thing (the adapters of me_adapters.dart go the other way).
import 'package:go_router/go_router.dart';

import '../../features/directory/presentation/account_messenger_screen.dart';
import '../../features/directory/presentation/connections_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/me/presentation/me_data_tab.dart';
import '../../features/me/presentation/me_messages_tab.dart';
import '../../features/me/presentation/me_personal_shell.dart';
import '../../features/me/presentation/me_shell.dart';
import '../../features/me/presentation/public_person_screen.dart';
import '../../features/me/providers/personal_shell_providers.dart';
import '../../features/money/presentation/screens/my_finances_screen.dart';
import '../../features/profile/presentation/screens/profiles_screen.dart';
import '../route_env.dart';
import 'me_adapters.dart';

/// Routes of the me feature.
List<RouteBase> meRoutes(RouteEnv env) {
  bool on() => env.mounted && env.ref.read(personalShellEnabledProvider);
  // The flag off: a personal-shell address leads to its legacy screen. Only
  // the route the location ends on answers: a parent's redirect runs first,
  // and `/me/account/connections` must reach the connections' own answer.
  GoRouterRedirect whenOff(String Function(GoRouterState state) legacy) =>
      (context, state) =>
          on() || state.matchedLocation != state.uri.path ? null : legacy(state);
  String query(GoRouterState state, String key) =>
      state.uri.queryParameters[key] ?? '';
  return [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MeShellSwitch(
        navigationShell: navigationShell,
        path: state.uri.path,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.home.path,
              // #1823 the Me layer; a legacy `tab` names its destination.
              redirect: (context, state) =>
                  on() ? personalShellAddressOf(state.uri) : null,
              builder: (context, state) =>
                  MeHomeRoot(tab: state.uri.queryParameters['tab']),
              routes: [
                GoRoute(
                  path: 'account',
                  redirect: whenOff((_) => '/me?tab=me'),
                  builder: (context, state) => const MeAccountPage(),
                  routes: [
                    GoRoute(
                      path: 'connections',
                      redirect: whenOff((_) => '/connections'),
                      builder: (context, state) => const ConnectionsScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.spaces.path,
              redirect: whenOff((_) => '/me'),
              builder: (context, state) => const ProfilesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.discover.path,
              redirect: whenOff((_) => '/me?tab=discover'),
              builder: (context, state) =>
                  const DirectoryScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.messages.path,
              redirect: whenOff((_) => '/me?tab=messages'),
              builder: (context, state) => const MeMessagesTab(),
              routes: [
                // `/me/messages/thread`, `/inquiries`, `/starred` and
                // `/new-group` are pages the router registers before this
                // list (page_routes.dart), so they match ahead of `:ref`.
                GoRoute(
                  path: 'new',
                  redirect: whenOff((state) => withQuery('/account-messages',
                      pickQuery(state.uri, const ['source', 'name']))),
                  builder: (context, state) => AccountMessengerScreen(
                    source: query(state, 'source'),
                    name: query(state, 'name'),
                  ),
                ),
                GoRoute(
                  path: ':ref',
                  redirect: whenOff((state) => withQuery('/account-messages', {
                        ...pickQuery(state.uri, const ['source', 'name']),
                        'recipient': state.pathParameters['ref'] ?? '',
                      })),
                  builder: (context, state) => AccountMessengerScreen(
                    source: query(state, 'source'),
                    recipient: state.pathParameters['ref'],
                    name: query(state, 'name'),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.data.path,
              redirect: whenOff((state) => withQuery('/account-activity',
                  pickQuery(state.uri, const ['workspace']))),
              builder: (context, state) => MeDataTab(
                view: MeDataView.fromQuery(state.uri.queryParameters['view']),
                workspaceId: state.uri.queryParameters['workspace'],
                finances: MyFinancesScreen(
                    workspaceId: state.uri.queryParameters['workspace']),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/p/:id',
      builder: (context, state) =>
          PublicPersonScreen(userId: state.pathParameters['id'] ?? ''),
    ), // #2211
  ];
}
