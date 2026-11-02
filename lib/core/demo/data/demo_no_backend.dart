// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3235 — the demo has no backend, and says so when asked for one.
//
// A signed-out visitor used to reach the demo with an anonymous global
// Supabase client, so a provider that escaped the overrides met row-level
// security. A signed-in person's visit keeps the LIVE session on that
// global client, so the same escape would act as them on real data. The
// Demo container therefore replaces the context clients with this stand-in:
// any use — a table, a function, storage, auth, realtime — throws, instead
// of reaching a server.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/context_client_providers.dart';
import '../../backend/context_clients.dart';

/// Thrown by every use of the Demo's stand-in client.
@visibleForTesting
class DemoHasNoBackend implements Exception {
  const DemoHasNoBackend();

  @override
  String toString() => 'DemoHasNoBackend: the demo has no backend';
}

/// A [SupabaseClient] that refuses everything.
@visibleForTesting
class DemoNoBackendClient implements SupabaseClient {
  const DemoNoBackendClient();

  @override
  Object? noSuchMethod(Invocation invocation) => throw const DemoHasNoBackend();
}

/// What the Demo container overrides: every context client is the refusal.
List<Override> demoNoBackendOverrides() => [
  contextClientsProvider.overrideWith(
    (ref) => ContextClients(const DemoNoBackendClient()),
  ),
];
