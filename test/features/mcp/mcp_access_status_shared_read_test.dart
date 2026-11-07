// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3377 -- "what this database lets the account do" is one fact. The
// assistants screen shows it twice (the eligibility section and the access
// status), and every change re-read it twice. For the backend this app talks to
// the status takes the read the eligibility section already makes (through the
// context's supersession guard); a context on ANOTHER installation reads its
// own, from its own repositories.
import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/mcp/application/mcp_client_registry.dart';
import 'package:deskilo/features/mcp/application/mcp_commands.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = 'aaaaaaaa-0000-4000-8000-000000000001';
const _other = 'bbbbbbbb-0000-4000-8000-000000000002';

/// Counts the capability reads the target's own repositories answer.
class _Counting extends FakeIdentityBindingRepository {
  int reads = 0;

  @override
  Future<DatabaseCapabilities> databaseCapabilities() {
    reads++;
    return super.databaseCapabilities();
  }
}

class _Client implements McpTargetClient {
  _Client(this.key, this.repositories);
  @override
  final McpTargetKey key;
  final McpRepositories repositories;
  @override
  Future<T> run<T>(Future<T> Function(McpRepositories) action) =>
      action(repositories);
  @override
  Future<void> dispose() async {}
}

VerifiedMcpTarget _target(String installation) => VerifiedMcpTarget(
  installationId: installation,
  issuer: 'https://id.test',
  account: 'user-1',
);

void main() {
  late _Counting identity;
  late int sharedReads;
  late ProviderContainer container;
  late VerifiedMcpTarget home;
  late VerifiedMcpTarget other;

  setUp(() async {
    identity = _Counting();
    sharedReads = 0;
    home = _target(_home);
    other = _target(_other);
    final repos = McpRepositories(
      admin: FakeMcpAdminRepository(),
      connections: FakeMcpConnectionRepository(),
      confirmations: FakeActionConfirmationRepository(),
      identity: identity,
      secondFactor: FakeSecondFactorRepository(),
    );
    final registry = McpClientRegistry((key, _) => _Client(key, repos));
    await registry.register(home);
    await registry.register(other);
    container = ProviderContainer(
      overrides: [
        mcpClientRegistryProvider.overrideWithValue(registry),
        mcpCommandsProvider.overrideWithValue(McpCommands(registry)),
        activeMcpTargetProvider.overrideWith((ref) async => home),
        myDatabaseCapabilitiesProvider.overrideWith((ref) async {
          sharedReads++;
          return const DatabaseCapabilities(
            eligibility: McpEligibility.notRequested,
          );
        }),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  Future<void> statusOf(McpContextRef scope) async {
    final p = mcpAccessStatusProvider(scope);
    final sub = container.listen(p, (_, _) {});
    addTearDown(sub.close);
    await container.read(p.future);
  }

  test('the status of the backend this app talks to takes the shared read: '
      'the target\'s own repositories are not asked', () async {
    final eligibility = container.listen(
      myDatabaseCapabilitiesProvider,
      (_, _) {},
    );
    addTearDown(eligibility.close);
    await container.read(myDatabaseCapabilitiesProvider.future);
    await statusOf(home.workspace('ws-1'));
    expect(sharedReads, 1, reason: 'one read for both, not one each');
    expect(identity.reads, 0);
  });

  test('a change re-reads the fact once for both', () async {
    final eligibility = container.listen(
      myDatabaseCapabilitiesProvider,
      (_, _) {},
    );
    addTearDown(eligibility.close);
    await statusOf(home.workspace('ws-1'));
    expect(sharedReads, 1);
    container
      ..invalidate(myDatabaseCapabilitiesProvider)
      ..invalidate(mcpAccessStatusProvider);
    await statusOf(home.workspace('ws-1'));
    expect(sharedReads, 2, reason: 'the invalidation re-reads once');
    expect(identity.reads, 0);
  });

  test(
    'a context on another installation reads its own capabilities',
    () async {
      await statusOf(other.workspace('ws-9'));
      expect(
        identity.reads,
        1,
        reason: 'the other installation is asked, not the home one',
      );
      expect(sharedReads, 0);
    },
  );
}
