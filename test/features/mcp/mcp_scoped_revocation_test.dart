// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1631 — a revocation invalidates exactly what the server says it ended,
// on the installation that answered. The workspaces a screen was still
// listing are not what ended: the server's answer is. An answer that names
// another installation is a typed refusal and is never published, and a
// late answer after the target was revoked is discarded. The same account
// UUID and workspace id on a second installation are never touched.
import 'dart:async';

import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/mcp/application/assistant_access.dart';
import 'package:deskilo/features/mcp/application/mcp_client_registry.dart';
import 'package:deskilo/features/mcp/application/mcp_commands.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:flutter_test/flutter_test.dart';

const _instA = 'aaaaaaaa-0000-4000-8000-000000000031';
const _instB = 'bbbbbbbb-0000-4000-8000-000000000031';
const _account = '11111111-2222-4333-8444-555555551631';

/// A server whose revocation answer the test can hold back.
class _Connections extends FakeMcpConnectionRepository {
  _Connections(String installationId) : super(installationId: installationId);
  Completer<void>? gate;

  @override
  Future<McpRevocation> revokeScope(String clientId, String workspaceId) async {
    final answer = await super.revokeScope(clientId, workspaceId);
    await gate?.future;
    return answer;
  }
}

class _Client implements McpTargetClient {
  _Client(this.key, this.connections);
  @override
  final McpTargetKey key;
  final _Connections connections;

  @override
  Future<T> run<T>(Future<T> Function(McpRepositories) action) => action(
    McpRepositories(
      admin: FakeMcpAdminRepository(),
      connections: connections,
      confirmations: FakeActionConfirmationRepository(),
      identity: FakeIdentityBindingRepository(),
      secondFactor: FakeSecondFactorRepository(),
    ),
  );

  @override
  Future<void> dispose() async {}
}

class _World {
  final servers = {_instA: _Connections(_instA), _instB: _Connections(_instB)};
  late final registry = McpClientRegistry(
    (key, t) => _Client(key, servers[t.installationId]!),
  );
  late final commands = McpCommands(registry);
  late final access = AssistantAccess(
    commands,
    FakeIdentityBindingRepository(),
  );
  final a = VerifiedMcpTarget(
    installationId: _instA,
    issuer: 'https://id.a.test',
    account: _account,
  );
  final b = VerifiedMcpTarget(
    installationId: _instB,
    issuer: 'https://id.b.test',
    account: _account,
  );

  Future<void> registerBoth() async {
    await registry.register(a);
    await registry.register(b);
  }
}

/// What the screen shows: the assistant on two workspaces of [t].
McpConnectionInfo _shown(VerifiedMcpTarget t) => const McpConnectionInfo(
  clientId: 'claude',
  clientName: 'Assistant',
  workspaces: [
    ConsentWorkspace(id: 'wa', name: 'Kraftwerk', operations: ['check_in']),
    ConsentWorkspace(id: 'wb', name: 'Atelier', operations: ['check_in']),
  ],
).withScope(t.instance);

void main() {
  test('the server answer is parsed as the revocation contract states it', () {
    // The exact shape 96_scoped_invalidation.sql asserts for 0310.
    final ended = McpRevocation.fromJson({
      'installation_id': _instA.toUpperCase(),
      'scope': 'workspace',
      'client_id': 'claude',
      'workspaces': ['wa'],
      'connections': 0,
      'status': 'revoked',
    });
    expect(ended.installationId, _instA);
    expect(ended.workspaces, {'wa'});
    expect(ended.connectionEnded, isFalse);
    expect(McpRevocation.fromJson(null).installationId, isNull);
    expect(
      McpRevocation.fromJson({'status': 'revoked'}).installationId,
      isNull,
      reason: 'an answer that names no installation is nobody\'s answer',
    );
  });

  test(
    'a disconnect ends what the server ended, not the list on screen',
    () async {
      final w = _World();
      await w.registerBoth();
      // The server holds only wa; wb was already revoked elsewhere.
      w.servers[_instA]!.live.add(
        const McpConnectionInfo(
          clientId: 'claude',
          clientName: 'Assistant',
          workspaces: [
            ConsentWorkspace(
              id: 'wa',
              name: 'Kraftwerk',
              operations: ['check_in'],
            ),
          ],
        ),
      );
      final result = await w.access.disconnect(_shown(w.a));
      expect(result.workspaces, {'wa'});
      expect(result.ends(w.a.workspace('wa')), isTrue);
      expect(result.ends(w.a.workspace('wb')), isFalse);
      expect(result.ends(w.b.workspace('wa')), isFalse);
      expect(w.servers[_instB]!.calls, isEmpty);
    },
  );

  test(
    'an answer naming another installation is refused, never published',
    () async {
      final w = _World();
      await w.registerBoth();
      w.servers[_instA]!.nextRevocation = const McpRevocation(
        installationId: _instB,
        workspaces: {'wa'},
      );
      await expectLater(
        w.access.removeWorkspace(_shown(w.a), 'wa'),
        throwsA(isA<McpProvenanceMismatch>()),
      );
      w.servers[_instA]!.nextRevocation = const McpRevocation(
        installationId: null,
        workspaces: {'wa'},
      );
      await expectLater(
        w.access.removeWorkspace(_shown(w.a), 'wa'),
        throwsA(isA<McpProvenanceMismatch>()),
        reason: 'an answer that names no installation is refused too',
      );
    },
  );

  test('a workspace removal on A invalidates A\'s key only', () async {
    final w = _World();
    await w.registerBoth();
    final result = await w.access.removeWorkspace(_shown(w.a), 'wa');
    expect(result.scope, McpDisconnectScope.workspace);
    expect(result.ends(w.a.workspace('wa')), isTrue);
    expect(result.ends(w.a.workspace('wb')), isFalse);
    expect(result.ends(w.b.workspace('wa')), isFalse);
    expect(w.servers[_instA]!.calls, ['revokeScope:claude:wa']);
    expect(w.servers[_instB]!.calls, isEmpty);
  });

  test(
    'a late revocation answer after the target was revoked is discarded',
    () async {
      final w = _World();
      await w.registerBoth();
      final gate = Completer<void>();
      w.servers[_instA]!.gate = gate;
      final pending = w.access.removeWorkspace(_shown(w.a), 'wa');
      await Future<void>.value();
      await w.registry.revokeTarget(_instA);
      gate.complete();
      await expectLater(pending, throwsA(isA<McpContextSuperseded>()));
      expect(
        w.servers[_instA]!.calls,
        ['revokeScope:claude:wa'],
        reason:
            'the server may have committed it; the client only refuses to '
            'publish the late answer as current',
      );
      final onB = await w.access.removeWorkspace(_shown(w.b), 'wa');
      expect(onB.ends(w.b.workspace('wa')), isTrue);
    },
  );
}
