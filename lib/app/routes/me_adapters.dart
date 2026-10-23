// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The addresses of the personal layer, both ways. While the personal shell
// is on, a legacy personal path (`/me?tab=`, `/account-messages`,
// `/account-activity`, `/profiles`, `/connections`) keeps its meaning at its
// new address; while it is off, a personal-shell path leads back to the
// legacy screen that holds the same thing (me_routes.dart). The mapping is a
// pure function of the URI; the hook reads the flag once per redirect.
import 'package:go_router/go_router.dart';

import '../../features/me/presentation/me_shell.dart';
import '../../features/me/providers/personal_shell_providers.dart';
import '../route_env.dart';

/// The redirect of a legacy personal route: its personal-shell address while
/// the shell is on, null (the legacy screen stays) otherwise.
String? personalShellAdapter(RouteEnv env, GoRouterState state) {
  if (!env.mounted || !env.ref.read(personalShellEnabledProvider)) return null;
  return personalShellAddressOf(state.uri);
}

/// The personal-shell address of a legacy personal [uri], or null for a
/// location the shell does not relocate (`/me` itself, without a `tab`).
String? personalShellAddressOf(Uri uri) {
  final q = uri.queryParameters;
  switch (uri.path) {
    case '/me':
      final tab = q['tab'];
      return tab == null ? null : MeTab.fromQuery(tab).path;
    case '/account-messages':
      final recipient = q['recipient'] ?? '';
      return withQuery(
        recipient.isEmpty
            ? '${MeTab.messages.path}/new'
            : '${MeTab.messages.path}/${Uri.encodeComponent(recipient)}',
        pickQuery(uri, const ['source', 'name']),
      );
    case '/account-activity':
      return withQuery(MeTab.data.path,
          {'view': 'finances', ...pickQuery(uri, const ['workspace'])});
    case '/profiles':
      return MeTab.spaces.path;
    case '/connections':
      return '${MeTab.me.path}/connections';
  }
  return null;
}

/// [path] with [query], or [path] alone when there is nothing to carry.
String withQuery(String path, Map<String, String> query) =>
    Uri(path: path, queryParameters: query.isEmpty ? null : query).toString();

/// The non-empty values of [keys] in [uri]'s query: what an adapter carries
/// across, and nothing else.
Map<String, String> pickQuery(Uri uri, List<String> keys) => {
      for (final key in keys)
        if (uri.queryParameters[key] case final value? when value.isNotEmpty)
          key: value,
    };
