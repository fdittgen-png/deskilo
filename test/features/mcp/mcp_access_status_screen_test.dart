// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — the Assistants screen shows the six separate facts the server
// answers for the selected workspace (identity, database approval, the
// owner's offer, role, consent, server) and the one next step, with who
// takes it; an unlinked identity offers the linked-accounts screen and the
// tap goes there. Below it, read-only, the other connected installations,
// each asked through its own registry client: A failing reads "could not
// be asked" while B, asked at the same time, shows its own answer. The
// strings exist in five languages (French rendered here; parity is the
// l10n gate's).
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/mcp/application/mcp_client_registry.dart';
import 'package:deskilo/features/mcp/application/mcp_commands.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:deskilo/features/mcp/presentation/assistants_screen.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _instA = 'aaaaaaaa-0000-4000-8000-0000000000a1';
const _instB = 'bbbbbbbb-0000-4000-8000-0000000000b1';

FakeIdentityBindingRepository _identity(
  IdentityBindingState state,
  McpEligibility eligibility,
) =>
    FakeIdentityBindingRepository(initial: IdentityBindingStatus(state: state))
      ..capabilities = DatabaseCapabilities(eligibility: eligibility);

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AssistantsScreen()),
      GoRoute(
        path: '/linked-accounts',
        builder: (_, _) => const Text('linked', key: ValueKey('linked-page')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// A connected installation answering through [repositories], or failing.
class _Client implements McpTargetClient {
  _Client(this.key, this.repositories);
  @override
  final McpTargetKey key;
  final McpRepositories? repositories;

  @override
  Future<T> run<T>(Future<T> Function(McpRepositories) action) {
    final r = repositories;
    if (r == null) return Future.error(StateError('target unreachable'));
    return action(r);
  }

  @override
  Future<void> dispose() async {}
}

McpRepositories _bundle(FakeIdentityBindingRepository identity) =>
    McpRepositories(
      admin: FakeMcpAdminRepository(),
      connections: FakeMcpConnectionRepository(),
      confirmations: FakeActionConfirmationRepository(),
      identity: identity,
      secondFactor: FakeSecondFactorRepository(),
    );

ConnectedInstallation _source(String host, String installation) =>
    ConnectedInstallation(
      endpoint: BackendEndpoint('https://$host', 'sb_publishable_x_target'),
      account: '$host-user',
      installationId: installation,
    );

void main() {
  testWidgets('the six facts and the next step, with who takes it', (
    tester,
  ) async {
    await _pump(
      tester,
      standardTestOverrides(
        identityBinding: _identity(
          IdentityBindingState.verified,
          McpEligibility.requested,
        ),
      ),
    );
    expect(_key('mcp-status'), findsOneWidget);
    for (final k in [
      'mcp-status-identity-verified',
      'mcp-status-eligibility-pending',
      'mcp-status-exposure-disabled',
      'mcp-status-role-unavailable',
      'mcp-status-consent-missing',
      'mcp-status-backend-available',
      'mcp-status-next-awaitEligibility',
    ]) {
      expect(_key(k), findsOneWidget, reason: k);
    }
    expect(
      find.text('Next: a database administrator decides your request.'),
      findsOneWidget,
    );
    expect(_key('mcp-status-link-identity'), findsNothing);
    expect(_key('mcp-overview-title'), findsNothing);
  });

  testWidgets('an unlinked identity is the next step, and the button '
      'confirms it here — not the sign-in methods page', (tester) async {
    final identity = _identity(
      IdentityBindingState.unlinked,
      McpEligibility.noIdentity,
    )..finalizeAnswer =
        const IdentityBindingStatus(state: IdentityBindingState.verified);
    await _pump(tester, standardTestOverrides(identityBinding: identity));
    expect(_key('mcp-status-identity-unlinked'), findsOneWidget);
    expect(_key('mcp-status-next-linkIdentity'), findsOneWidget);
    // The role cannot be judged before approval: not "unknown".
    expect(find.text('After the step above'), findsWidgets);
    await tester.tap(_key('mcp-status-link-identity'));
    await tester.pumpAndSettle();
    expect(identity.finalizeCalls, 1);
    expect(_key('linked-page'), findsNothing);
    expect(_key('mcp-status-identity-verified'), findsOneWidget);
  });

  testWidgets('a refused confirmation says why', (tester) async {
    final identity = _identity(
      IdentityBindingState.unlinked,
      McpEligibility.noIdentity,
    )..finalizeAnswer =
        const IdentityBindingStatus(state: IdentityBindingState.ineligible);
    await _pump(tester, standardTestOverrides(identityBinding: identity));
    await tester.tap(_key('mcp-status-link-identity'));
    await tester.pumpAndSettle();
    expect(find.textContaining('confirm your e-mail address'), findsOneWidget);
  });

  testWidgets('a server that predates the answers reads unknown and '
      'incompatible, never a permissive state', (tester) async {
    await _pump(tester, standardTestOverrides());
    expect(_key('mcp-status-identity-unavailable'), findsOneWidget);
    expect(_key('mcp-status-eligibility-unavailable'), findsOneWidget);
    expect(_key('mcp-status-backend-incompatible'), findsOneWidget);
    expect(_key('mcp-status-next-unavailable'), findsOneWidget);
  });

  testWidgets('French: the facts read in the workspace language', (
    tester,
  ) async {
    await _pump(
      tester,
      standardTestOverrides(
        identityBinding: _identity(
          IdentityBindingState.verified,
          McpEligibility.notRequested,
        ),
      ),
      locale: const Locale('fr'),
    );
    expect(find.text('Où vous en êtes ici'), findsOneWidget);
    expect(find.text('Non demandée'), findsOneWidget);
    expect(
      find.text(
        'Prochaine étape : vous demandez l\'approbation aux administrateurs '
        'de cette base de données.',
      ),
      findsOneWidget,
    );
  });

  group('connected installations overview', () {
    late McpClientRegistry registry;
    late List<McpTargetKey> asked;

    List<Override> overrides() {
      asked = [];
      final active = _identity(
        IdentityBindingState.verified,
        McpEligibility.eligible,
      );
      final b = _identity(
        IdentityBindingState.verified,
        McpEligibility.eligible,
      );
      registry = McpClientRegistry((key, target) {
        asked.add(key);
        return _Client(key, switch (target.source) {
          '' => _bundle(active),
          'https://b.example' => _bundle(b),
          _ => null, // A is unreachable.
        });
      });
      return [
        ...standardTestOverrides(
          identityBinding: active,
          connectedSources: [
            _source('a.example', _instA),
            _source('b.example', _instB),
            // A record whose id cannot be verified is never registered.
            _source('c.example', 'not-an-installation'),
          ],
        ),
        mcpClientRegistryProvider.overrideWithValue(registry),
        mcpCommandsProvider.overrideWithValue(McpCommands(registry)),
      ];
    }

    testWidgets('A fails while B answers: each shows its own state', (
      tester,
    ) async {
      await _pump(tester, overrides());
      expect(_key('mcp-overview-a.example-unavailable'), findsOneWidget);
      expect(_key('mcp-overview-b.example-approved'), findsOneWidget);
      expect(_key('mcp-overview-c.example-unavailable'), findsOneWidget);
      expect(
        _key('mcp-status-eligibility-approved'),
        findsOneWidget,
        reason: 'the active workspace status is unaffected by A',
      );
      expect({
        for (final k in asked) k.installationId,
      }, containsAll([_instA, _instB]));
      expect(
        asked.where((k) => k.installationId == 'not-an-installation'),
        isEmpty,
      );
    });

    test(
      'the provider: one outcome per installation, in source order',
      () async {
        final c = ProviderContainer(
          overrides: overrides(),
          retry: (_, _) => null,
        );
        addTearDown(c.dispose);
        final list = await c.read(connectedMcpOverviewProvider.future);
        expect(
          [for (final s in list) s.source],
          ['https://a.example', 'https://b.example', 'https://c.example'],
        );
        expect(
          [for (final s in list) s.eligibility.name],
          ['unavailable', 'approved', 'unavailable'],
        );
        // B's answer came through B's own client, keyed by B.
        expect(
          registry.keys.where((k) => k.installationId == _instB),
          hasLength(1),
        );
      },
    );
  });
}
