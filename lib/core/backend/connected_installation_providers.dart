// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import 'auth_secret_store.dart';
import 'connected_installations.dart';
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
