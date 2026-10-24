// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the Me layer and public profiles.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
//
// The `personalShell` flag decides the route TABLE, not a redirect: on, Me is
// one StatefulShellRoute with five branches — Overview, My spaces, Discover,
// Messages, My data — each a route-owned destination with its own navigator,
// so a switch restores the branch's stack; off, `/me` is the four-tab shell
// exactly as before (a plain route, so pushing Me over pages stacked above it
// keeps working), and every other personal-shell address leads to the legacy
// screen that holds the same thing. The flag is WATCHED here: the router is
// rebuilt when it flips, which is the one way a route table changes.
import 'package:go_router/go_router.dart';

import '../../features/directory/presentation/account_messenger_screen.dart';
import '../../features/directory/presentation/connections_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/me/presentation/me_data_tab.dart';
import '../../features/me/presentation/me_home_tab.dart';
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
List<RouteBase> meRoutes(RouteEnv env) => [
      if (env.ref.watch(personalShellEnabledProvider))
        _personalShell()
      else
        ..._legacyMe(),
      GoRoute(
        path: '/p/:id',
        builder: (context, state) =>
            PublicPersonScreen(userId: state.pathParameters['id'] ?? ''),
      ), // #2211
    ];

String _query(GoRouterState state, String key) =>
    state.uri.queryParameters[key] ?? '';

/// The four-tab shell at `/me` (#1823), and every personal-shell address
/// leading to the legacy screen that holds the same thing.
List<RouteBase> _legacyMe() => [
      GoRoute(
        path: MeTab.home.path,
        builder: (context, state) =>
            MeShell(tab: MeTab.fromQuery(state.uri.queryParameters['tab'])),
      ),
      GoRoute(path: MeTab.spaces.path, redirect: (context, state) => '/me'),
      GoRoute(
        path: MeTab.discover.path,
        redirect: (context, state) => '/me?tab=discover',
      ),
      GoRoute(
        path: MeTab.messages.path,
        redirect: (context, state) => '/me?tab=messages',
      ),
      GoRoute(
        path: '${MeTab.messages.path}/new',
        redirect: (context, state) => withQuery('/account-messages',
            pickQuery(state.uri, const ['source', 'name'])),
      ),
      GoRoute(
        path: '${MeTab.messages.path}/:ref',
        redirect: (context, state) => withQuery('/account-messages', {
          ...pickQuery(state.uri, const ['source', 'name']),
          'recipient': state.pathParameters['ref'] ?? '',
        }),
      ),
      GoRoute(
        path: MeTab.data.path,
        redirect: (context, state) => withQuery(
            '/account-activity', pickQuery(state.uri, const ['workspace'])),
      ),
      GoRoute(path: MeTab.me.path, redirect: (context, state) => '/me?tab=me'),
      GoRoute(
        path: '${MeTab.me.path}/connections',
        redirect: (context, state) => '/connections',
      ),
    ];

/// The personal shell: five branches, the account utility under Overview,
/// the conversation pages under Messages.
StatefulShellRoute _personalShell() => StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MePersonalShell(
        navigationShell: navigationShell,
        path: state.uri.path,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.home.path,
              // A legacy `tab` names its destination.
              redirect: (context, state) => personalShellAddressOf(state.uri),
              builder: (context, state) => const MeHomeTab(),
              routes: [
                GoRoute(
                  path: 'account',
                  builder: (context, state) => const MeAccountPage(),
                  routes: [
                    GoRoute(
                      path: 'connections',
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
              builder: (context, state) => const ProfilesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.discover.path,
              builder: (context, state) =>
                  const DirectoryScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.messages.path,
              builder: (context, state) => const MeMessagesTab(),
              routes: [
                // `/me/messages/thread`, `/inquiries`, `/starred` and
                // `/new-group` are pages the router registers before this
                // list (page_routes.dart), so they match ahead of `:ref`.
                GoRoute(
                  path: 'new',
                  builder: (context, state) => AccountMessengerScreen(
                    source: _query(state, 'source'),
                    name: _query(state, 'name'),
                  ),
                ),
                GoRoute(
                  path: ':ref',
                  builder: (context, state) => AccountMessengerScreen(
                    source: _query(state, 'source'),
                    recipient: state.pathParameters['ref'],
                    name: _query(state, 'name'),
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
    );
