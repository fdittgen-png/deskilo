// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import 'auth_callback_dispatch.dart';
import 'auth_callback_guard.dart';
import 'auth_secret_store.dart';
import 'connected_installations.dart';
import 'secondary_federation.dart';
part 'connected_installation_providers.g.dart';

@Riverpod(keepAlive: true)
ConnectedInstallations connectedInstallations(Ref ref) {
  ref.watch(authStateProvider);
  final connections = ConnectedInstallations(
    Supabase.instance.client,
    const PlatformAuthSecretStore(),
  );
  ref.onDispose(connections.close);
  return connections;
}

@riverpod
Future<List<ConnectedInstallation>> connectedSources(Ref ref) {
  if (ref.watch(authStateProvider).value == null) return Future.value([]);
  return ref.watch(connectedInstallationsProvider).list();
}

/// #1832 A — whether one connected target can be used now, and if not,
/// the typed reason; null means usable. Each target is asked on its own,
/// so one that is down leaves the others' rows usable.
@riverpod
Future<ConnectionFailure?> connectionHealth(Ref ref, String source) =>
    ref.watch(connectedInstallationsProvider).check(source);

/// #1834 — connecting another installation with the person's identity:
/// that server's own sign-in, its verified binding, the session kept in
/// the registry above. The one callback owner routes the browser return.
@Riverpod(keepAlive: true)
IdentityConnector identityConnector(Ref ref) {
  final federation = SecondaryFederation(
    active: Supabase.instance.client,
    registry: ref.watch(connectedInstallationsProvider),
    secrets: const PlatformAuthSecretStore(),
    callback:
        bootAuthCallbackGuard?.callback ?? Uri.parse('deskilo://auth-callback'),
    dispatcher: bootAuthCallbackDispatcher,
  );
  ref.onDispose(federation.dispose);
  return federation;
}
