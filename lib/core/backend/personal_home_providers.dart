// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the directory home from the installation's own declaration,
// read on the personal home (the installation this device booted on),
// anonymously. It replaces the constant that pinned the directory to the reference
// deployment whatever the installation said.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_settings.dart';
import 'context_client_providers.dart';
import 'origin_only_client.dart';
import 'personal_home.dart';

/// #2555 -- the endpoint of the installation this device booted on, as its
/// personal client names it. Never the selected workspace's host.
final personalEndpointProvider = Provider<BackendEndpoint>((ref) {
  final client = ref.watch(personalClientProvider);
  return BackendEndpoint(
    Uri.parse(client.rest.url).origin,
    client.auth.headers['apikey'] ?? '',
  );
});

/// Where the directory source list lives. Fails with
/// [PersonalHomeUnavailable] when the installation's declaration cannot be
/// used; it is never answered by another server instead.
///
/// The declaration is public (granted to `anon`), so it is read like every
/// other public discovery read: a fresh client with the publishable key
/// alone, behind [OriginOnlyClient]. A signed-in person's session never
/// accompanies it, and a redirect is never followed.
final directoryHomeProvider = FutureProvider<BackendEndpoint>((ref) async {
  final self = ref.watch(personalEndpointProvider);
  final client = SupabaseClient(
    self.url,
    self.key,
    httpClient: OriginOnlyClient(self.url, ref.watch(publicTransportProvider)()),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final PersonalHomeDeclaration declaration;
  try {
    declaration = await readPersonalHomeDeclaration(client);
  } finally {
    await client.dispose();
  }
  return directoryHomeOf(declaration, self: self);
}, retry: (_, _) => null);
