// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — an MCP management answer that names another workspace or another
// confirmation is a typed refusal, never published as the one asked for.
import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

McpPolicy _policy(String ws) => McpPolicy(
  workspaceId: ws,
  revision: 1,
  enabled: true,
  operations: const {'get_capabilities'},
  targetCeiling: 'own',
  featureEnabled: true,
  available: const ['get_capabilities'],
);

ProviderContainer _container(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('a policy answer for the workspace asked for is published', () async {
    final c = _container([
      mcpAdminRepositoryProvider.overrideWithValue(
        FakeMcpAdminRepository(policy: _policy('ws-a')),
      ),
    ]);
    final sub = c.listen(mcpPolicyProvider('ws-a'), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await c.read(mcpPolicyProvider('ws-a').future)).workspaceId,
      'ws-a',
    );
  });

  test(
    'a policy answer naming another workspace is refused, not shown',
    () async {
      final c = _container([
        mcpAdminRepositoryProvider.overrideWithValue(
          FakeMcpAdminRepository(policy: _policy('ws-b')),
        ),
      ]);
      final sub = c.listen(mcpPolicyProvider('ws-a'), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        c.read(mcpPolicyProvider('ws-a').future),
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
    final c = _container([
      actionConfirmationRepositoryProvider.overrideWithValue(repo),
    ]);
    final sub = c.listen(actionConfirmationProvider('c-1'), (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      c.read(actionConfirmationProvider('c-1').future),
      throwsA(isA<McpProvenanceMismatch>()),
    );
  });

  test('a context is its workspace and installation, nothing else', () {
    const a = McpContextRef(workspaceId: 'w', installationId: 'i1');
    expect(a, const McpContextRef(workspaceId: 'w', installationId: 'i1'));
    expect(
      a == const McpContextRef(workspaceId: 'w', installationId: 'i2'),
      isFalse,
      reason:
          'the same workspace id on another installation is another context',
    );
  });
}
