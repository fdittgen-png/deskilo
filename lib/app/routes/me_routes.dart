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
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/directory/domain/conversation_link.dart';
import '../../features/directory/presentation/account_messenger_screen.dart';
import '../../features/directory/presentation/connections_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/me/presentation/me_data_tab.dart';
import '../../features/me/presentation/me_home_tab.dart';
import '../../features/me/presentation/me_messages_tab.dart';
import '../../features/me/presentation/me_personal_shell.dart';
import '../../features/me/presentation/me_shell.dart';
import '../../features/me/presentation/personal_branch_storage.dart';
import '../../features/me/presentation/personal_spaces_view.dart';
import '../../features/me/presentation/public_person_screen.dart';
import '../../features/me/providers/personal_return_providers.dart';
import '../../features/me/providers/personal_shell_providers.dart';
import '../../features/money/presentation/screens/my_finances_screen.dart';
import '../../features/profile/presentation/screens/profiles_screen.dart';
import '../../features/reservations/presentation/widgets/my_reservations_body.dart';
import '../route_env.dart';
import 'me_adapters.dart';

/// Routes of the me feature.
List<RouteBase> meRoutes(RouteEnv env) => [
      if (env.ref.watch(personalShellEnabledProvider))
        _personalShell(env)
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
        builder: (context, state) => MeShell(
          tab: MeTab.fromQuery(state.uri.queryParameters['tab']),
          link: state.uri.queryParameters[ConversationLink.parameter],
        ),
      ),
      GoRoute(path: MeTab.spaces.path, redirect: (context, state) => '/me'),
      GoRoute(
        path: personalSpacesManagePath,
        redirect: (context, state) => '/profiles',
      ),
      GoRoute(
        path: MeTab.discover.path,
        redirect: (context, state) => '/me?tab=discover',
      ),
      GoRoute(
        path: MeTab.messages.path,
        // #2556 — a link to one conversation is followed here too.
        redirect: (context, state) => withQuery('/me', {
          'tab': MeTab.messages.wire,
          ...pickQuery(state.uri, const [ConversationLink.parameter]),
        }),
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

/// A destination's page, keeping its scroll offsets beyond the shell.
PersonalBranchStorage _kept(MeTab tab, Widget page) =>
    PersonalBranchStorage(branch: tab.wire, child: page);

/// Me's bare home, reached again after a stay in a space, lands where the
/// person entered the space from (personal_return_providers.dart).
String? _resume(RouteEnv env, GoRouterState state) {
  final uri = state.uri;
  if (!env.mounted) return null;
  if (uri.path != MeTab.home.path || uri.query.isNotEmpty) return null;
  return env.ref
      .read(personalReturnProvider)
      .resumeFor(env.ref.read(authStateProvider).value);
}

/// The personal shell: five branches, the account utility under Overview,
/// the conversation pages under Messages.
StatefulShellRoute _personalShell(RouteEnv env) =>
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MePersonalShell(
        navigationShell: navigationShell,
        path: state.uri.path,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.home.path,
              // A legacy `tab` names its destination; a return from a space
              // the place it was entered from.
              redirect: (context, state) =>
                  personalShellAddressOf(state.uri) ?? _resume(env, state),
              builder: (context, state) =>
                  _kept(MeTab.home, const MeHomeTab()),
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
              // #2554 — every space my account names, by its host.
              builder: (context, state) =>
                  _kept(MeTab.spaces, const PersonalSpacesView()),
              routes: [
                // This server's spaces to manage: default, home site,
                // environments, the platform tools.
                GoRoute(
                  path: 'manage',
                  builder: (context, state) => const ProfilesScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.discover.path,
              builder: (context, state) => _kept(
                  MeTab.discover, const DirectoryScreen(embedded: true)),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: MeTab.messages.path,
              // #2556 — `?conversation=` selects one once its source says
              // it is this person's (ConversationLink).
              builder: (context, state) => _kept(
                MeTab.messages,
                MeMessagesTab(
                  link: state.uri.queryParameters[ConversationLink.parameter],
                ),
              ),
              routes: [
                // `/me/messages/thread`, `/inquiries`, `/starred` and
                // `/new-group` are pages the router registers before this
                // list (page_routes.dart), so they match ahead of `:ref`.
                GoRoute(
                  path: 'new',
                  // #2556 — a person or group picked here opens in the
                  // messenger's pane.
                  builder: (context, state) => AccountMessengerScreen(
                    source: _query(state, 'source'),
                    name: _query(state, 'name'),
                    handOffTo: MeTab.messages.path,
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
              builder: (context, state) => _kept(
                MeTab.data,
                MeDataTab(
                  view: MeDataView.fromQuery(state.uri.queryParameters['view']),
                  workspaceId: state.uri.queryParameters['workspace'],
                  finances: MyFinancesScreen(
                      workspaceId: state.uri.queryParameters['workspace']),
                  reservations: const MyReservationsBody(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
