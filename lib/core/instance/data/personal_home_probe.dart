// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the network half of the wizard's personal-home check: what the
// named installation says about itself, read anonymously.
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/connected_installations.dart';
import '../../backend/context_clients.dart';
import '../../public_network/public_network_negotiator.dart';
import '../instance_network.dart';

/// Reads [home]'s descriptor and installation id with its publishable key,
/// no session, behind [OriginOnlyClient].
Future<PersonalHomeFacts> probePersonalHome(
  PersonalHomeEndpoint home, {
  http.Client Function()? transport,
}) async {
  final client = SupabaseClient(
    home.url,
    home.key,
    httpClient: OriginOnlyClient(home.url, (transport ?? http.Client.new)()),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  try {
    final profile = readPublicDescriptor(
      await client
          .rpc<Object?>('public_network_descriptor')
          .timeout(const Duration(seconds: 12)),
    );
    final id = await readInstallationId(client)
        .timeout(const Duration(seconds: 12));
    return switch (profile) {
      PublicNegotiatingServer(:final roles, :final roleCapabilities) => (
        roles: roles,
        capabilities: roleCapabilities,
        installationId: id,
      ),
      _ => (
        roles: const <String>[],
        capabilities: const <String>[],
        installationId: id,
      ),
    };
  } finally {
    await client.dispose();
  }
}
