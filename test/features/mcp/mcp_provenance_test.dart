// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — an MCP management answer that names another workspace or another
// confirmation is a typed refusal, never published as the one asked for.
import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart' show kTestInstallationId;

McpPolicy _policy(String ws) => McpPolicy(
  workspaceId: ws,
  revision: 1,
  enabled: true,
  operations: const {'get_capabilities'},
  targetCeiling: 'own',
  featureEnabled: true,
  available: const ['get_capabilities'],
);

const _ctx = McpContextRef(
  installationId: kTestInstallationId,
  account: 'user-1',
  workspaceId: 'ws-a',
);

ProviderContainer _container({
  FakeMcpAdminRepository? admin,
  FakeActionConfirmationRepository? confirmations,
}) {
  final c = ProviderContainer(
    overrides: [
      mcpAdminRepositoryProvider.overrideWithValue(
        admin ?? FakeMcpAdminRepository(),
      ),
      actionConfirmationRepositoryProvider.overrideWithValue(
        confirmations ?? FakeActionConfirmationRepository(),
      ),
      mcpConnectionRepositoryProvider.overrideWithValue(
        FakeMcpConnectionRepository(),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      identityBindingRepositoryProvider.overrideWithValue(
        FakeIdentityBindingRepository(),
      ),
      activeMcpTargetProvider.overrideWith(
        (ref) => fixedMcpTarget(ref, kTestInstallationId),
      ),
    ],
    retry: (_, _) => null,
  );
  addTearDown(c.dispose);
  return c;
}

/// The registry learns the test installation before a scoped read. A
/// listener keeps the (otherwise paused) sign-in stream flowing.
Future<void> _verified(ProviderContainer c) {
  final sub = c.listen(activeMcpTargetProvider, (_, _) {});
  addTearDown(sub.close);
  return c.read(activeMcpTargetProvider.future);
}

void main() {
  test('a policy answer for the workspace asked for is published', () async {
    final c = _container(admin: FakeMcpAdminRepository(policy: _policy('ws-a')));
    await _verified(c);
    final sub = c.listen(mcpPolicyProvider(_ctx), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await c.read(mcpPolicyProvider(_ctx).future)).workspaceId,
      'ws-a',
    );
  });

  test(
    'a policy answer naming another workspace is refused, not shown',
    () async {
      final c = _container(
        admin: FakeMcpAdminRepository(policy: _policy('ws-b')),
      );
      await _verified(c);
      final sub = c.listen(mcpPolicyProvider(_ctx), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        c.read(mcpPolicyProvider(_ctx).future),
        throwsA(
          isA<McpProvenanceMismatch>()
              .having((e) => e.expected, 'expected', 'ws-a')
              .having((e) => e.answered, 'answered', 'ws-b'),
        ),
      );
    },
  );

  test('a confirmation answer for another id is refused, not shown', () async {
    final repo = FakeActionConfirmationRepository()
      ..confirmations['c-1'] = const ActionConfirmation(
        id: 'c-2',
        status: ConfirmationStatus.pending,
      );
    final c = _container(confirmations: repo);
    final sub = c.listen(actionConfirmationProvider('c-1'), (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      c.read(actionConfirmationProvider('c-1').future),
      throwsA(isA<McpProvenanceMismatch>()),
    );
  });

  test('a context is its installation, account and workspace', () {
    const a = McpContextRef(workspaceId: 'w', installationId: 'i1', account: 'u');
    expect(
      a,
      const McpContextRef(workspaceId: 'w', installationId: 'i1', account: 'u'),
    );
    expect(
      a == const McpContextRef(workspaceId: 'w', installationId: 'i2', account: 'u'),
      isFalse,
      reason:
          'the same workspace id on another installation is another context',
    );
  });
}
