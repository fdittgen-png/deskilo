// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- installations over an in-memory wire, a real connection pool
// on the personal home's client, and the home's enrolled-host answer.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/workspace/domain/workspace_host.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'installation_auth_storage.dart' show MemorySecrets;
import 'native_federation_flow.dart' show session, user;

/// One installation at `https://<name>.example`, whose own
/// `installation_identity` answers [installationId].
class WireHost {
  WireHost(this.name, {String? installationId})
      : installationId = installationId ?? 'inst-$name';
  final String name;
  String installationId;
  final calls = <String>[];
  String get origin => 'https://$name.example';
  String get key => 'sb_publishable_${name}_target';
  BackendEndpoint get endpoint => BackendEndpoint(origin, key);

  /// The enrolment the personal home lists for this installation.
  WorkspaceHost enrolled({
    WorkspaceHostState state = WorkspaceHostState.available,
    String? id,
  }) =>
      WorkspaceHost(
        installationId: id ?? installationId,
        origin: origin,
        publishableKey: key,
        state: state,
      );

  Future<http.Response> handle(http.Request r) async {
    calls.add(r.url.path);
    final Object? body = switch (r.url.path) {
      '/auth/v1/token' => session('$name-user'),
      '/auth/v1/user' => user('$name-user'),
      '/rest/v1/installation_identity' => {'installation_id': installationId},
      '/rest/v1/rpc/create_workspace_once' => 'ws-on-$name',
      '/rest/v1/rpc/public_network_descriptor' => null,
      _ => <Object?>[],
    };
    if (body == null) {
      return http.Response(
        jsonEncode({'code': 'PGRST202', 'message': 'not found'}),
        404,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }
}

/// The personal home's answer, replaceable between reads.
class FakeWorkspaceHosts implements WorkspaceHostRepository {
  FakeWorkspaceHosts(this.answer);
  WorkspaceHosts answer;
  Exception? failure;
  int reads = 0;

  @override
  Future<WorkspaceHosts> fetchHosts() async {
    reads++;
    if (failure case final f?) throw f;
    return answer;
  }
}

/// [root] is the personal home the app is signed in to; the pool holds no
/// connection until a test connects one.
class HostsWorld {
  HostsWorld(this.hosts);
  final List<WireHost> hosts;
  late final SupabaseClient root;
  late final ConnectedInstallations pool;

  WireHost get home => hosts.first;

  http.Client wire() => MockClient(
        (r) => hosts
            .firstWhere((h) => h.name == r.url.host.split('.').first)
            .handle(r),
      );

  Future<void> open() async {
    root = SupabaseClient(
      home.origin,
      home.key,
      httpClient: wire(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await root.auth.setInitialSession(jsonEncode(session('${home.name}-user')));
    pool = ConnectedInstallations(root, MemorySecrets(), transport: wire);
  }

  Future<void> connect(WireHost host) =>
      pool.connect(host.endpoint, 'user@example.test', 'password');

  Future<void> close() async {
    pool.close();
    await root.dispose();
  }
}
