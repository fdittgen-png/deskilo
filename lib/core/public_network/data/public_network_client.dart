// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 B — the network half of negotiation: reads a target's descriptor
// anonymously (a fresh client behind OriginOnlyClient, publishable key, no
// session) and remembers it for this session. The decisions themselves are
// the pure functions of public_network_negotiator.dart.
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/connected_installations.dart';
import '../../trace/trace_logger.dart';
import '../public_network_negotiator.dart';
import '../public_network_operations.dart';
import '../public_network_spec.dart';

/// Reads descriptors over the network, anonymously, one per origin, and
/// remembers each for this session. A refusal by the server [forget]s it.
class PublicNetworkNegotiator {
  PublicNetworkNegotiator({http.Client Function()? transport})
    : transport = transport ?? http.Client.new;
  final http.Client Function() transport;
  final _profiles = <String, Future<PublicServerProfile>>{};

  static const _descriptor = PublicNetworkOperations.networkDescriptorRead;

  Future<PublicServerProfile> _read(String origin, String key) async {
    final client = SupabaseClient(
      origin,
      key,
      httpClient: OriginOnlyClient(origin, transport()),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      final raw = await client
          .rpc<Object?>(_descriptor.rpc!)
          .timeout(const Duration(seconds: 12));
      return readPublicDescriptor(raw);
    } on PostgrestException catch (e, st) {
      // The captured answer of a server from before negotiation.
      if (e.code != 'PGRST202') rethrow;
      TraceLogger.instance.log(
        TraceLevel.info,
        'public_network',
        '$origin has no descriptor: pre-negotiation baseline',
        stackTrace: st,
      );
      return const PublicServerProfile.baseline();
    } finally {
      await client.dispose();
    }
  }

  /// Negotiates [op] with the installation at [origin] (publishable [key]).
  Future<PublicNegotiation> negotiate(
    String origin,
    String key,
    PublicOperationSpec op,
  ) async {
    final PublicServerProfile profile;
    try {
      profile = await (_profiles[origin] ??= _read(origin, key));
    } catch (e, st) {
      _profiles.remove(origin)?.ignore();
      TraceLogger.instance.warn(
        'public_network',
        'descriptor unreachable',
        error: e.runtimeType,
        stackTrace: st,
      );
      throw PublicActionRefusal(op.id, PublicRefusalReason.unreachable);
    }
    return negotiatePublicOperation(profile, op);
  }

  /// Drops what [origin] said, so the next action asks again.
  void forget(String origin) => _profiles.remove(origin)?.ignore();
}
