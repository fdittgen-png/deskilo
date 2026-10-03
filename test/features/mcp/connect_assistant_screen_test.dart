// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — Connect an assistant, driven as a member would. Opening the page
// sends nothing. Every row says where it stands and who acts; the single-
// operator installation whose own request waits is sent to the
// installation console; a member waiting on the operator sees their name
// and copies a request. Each of the six assistants gets its own steps with
// this server's address filled in, and the one-click links open exactly
// the encoded install link. The test waits for a call newer than the one
// it started from. French is rendered once.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/instance_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/mcp/mcp_endpoint.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:deskilo/features/mcp/domain/mcp_usage.dart';
import 'package:deskilo/features/mcp/presentation/connect_assistant_screen.dart';
import 'package:deskilo/features/workspace/domain/instance_responsibles.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _ws = 'ws-1';
const _backend = 'https://abc.supabase.co';
final _url = Uri.parse('$_backend/functions/v1/deskilo-mcp');

McpPolicy _exposed() => const McpPolicy(
  workspaceId: _ws,
  revision: 1,
  enabled: true,
  operations: {'get_availability'},
  targetCeiling: 'own',
  featureEnabled: true,
  available: ['get_availability'],
);

FakeIdentityBindingRepository _identity({
  McpEligibility eligibility = McpEligibility.eligible,
  bool runtime = true,
  Duration left = const Duration(days: 80),
}) =>
    FakeIdentityBindingRepository(
        initial: const IdentityBindingStatus(
          state: IdentityBindingState.verified,
        ),
      )
      ..capabilities = DatabaseCapabilities(
        eligibility: eligibility,
        runtimeEnabled: runtime,
        eligibleUntil: eligibility == McpEligibility.eligible
            ? kTestNow.toUtc().add(left)
            : null,
      );

FakeMcpConnectionRepository _connections({bool eligible = true}) =>
    FakeMcpConnectionRepository(
      consent: ConsentOptions(
        eligible: eligible,
        workspaces: [
          if (eligible)
            const ConsentWorkspace(
              id: _ws,
              name: 'Test Space',
              operations: ['get_availability'],
            ),
        ],
      ),
    );

class _Harness {
  final launched = <Uri>[];
  final copied = <String>[];
}

Future<_Harness> _pump(
  WidgetTester tester, {
  FakeIdentityBindingRepository? identity,
  FakeMcpConnectionRepository? connections,
  FakeInstanceRepository? instance,
  FakeWorkspaceRepository? workspace,
  Set<WorkspacePermission> permissions = const {},
  bool featureOn = true,
  Locale locale = const Locale('en'),
}) async {
  final h = _Harness();
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        h.copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ConnectAssistantScreen()),
      GoRoute(
        path: '/installation/assistants',
        builder: (_, _) => const Text('console', key: ValueKey('console')),
      ),
      GoRoute(
        path: '/settings/assistant-setup',
        builder: (_, _) => const Text('setup', key: ValueKey('setup')),
      ),
      GoRoute(
        path: '/linked-accounts',
        builder: (_, _) => const Text('linked', key: ValueKey('linked')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          identityBinding: identity ?? _identity(),
          mcpAdmin: FakeMcpAdminRepository(policy: _exposed()),
          mcpConnections: connections ?? _connections(),
          workspace: workspace ?? FakeWorkspaceRepository.withWorkspace(),
          instance: instance,
        ),
        myPermissionsProvider.overrideWithValue(permissions),
        enabledFeaturesSyncProvider.overrideWithValue(
          featureOn ? const {WorkspaceFeature.mcpAccess} : const {},
        ),
        bootedBackendUrlProvider.overrideWithValue(_backend),
        linkLauncherProvider.overrideWithValue((uri) async {
          h.launched.add(uri);
          return true;
        }),
      ],
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
  return h;
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<SelectableText>(_key(key)).data!;

void main() {
  testWidgets('a ready member: every row is done but adding the connector, '
      'and nothing is sent on open', (tester) async {
    final connections = _connections();
    await _pump(tester, connections: connections);
    for (final k in [
      'mcp-connect-step-google-done',
      'mcp-connect-step-identity-done',
      'mcp-connect-step-access-done',
      'mcp-connect-step-workspace-done',
      'mcp-connect-step-server-done',
      'mcp-connect-step-connect-todo',
    ]) {
      expect(_key(k), findsOneWidget, reason: k);
    }
    expect(find.textContaining('80 days left'), findsOneWidget);
    expect(connections.calls, isEmpty);
    expect(_text(tester, 'mcp-connect-url'), '$_url');
  });

  testWidgets('each assistant gets its own steps and the exact link', (
    tester,
  ) async {
    final h = await _pump(tester);

    // Claude is first; its button opens Claude's connector settings.
    expect(_key('mcp-connect-panel-claude'), findsOneWidget);
    await _tap(tester, 'mcp-connect-claude-open');
    expect(h.launched.last, claudeConnectorsUri);
    await _tap(tester, 'mcp-connect-copy-url');
    expect(h.copied.last, '$_url');

    await _tap(tester, 'mcp-connect-tab-claudeCode');
    expect(
      _text(tester, 'mcp-connect-code-command'),
      'claude mcp add --transport http deskilo $_url',
    );
    await _tap(tester, 'mcp-connect-copy-code-command');
    expect(h.copied.last, 'claude mcp add --transport http deskilo $_url');

    await _tap(tester, 'mcp-connect-tab-chatgpt');
    expect(find.textContaining('developer mode'), findsOneWidget);
    expect(find.textContaining('paid ChatGPT plan'), findsOneWidget);

    await _tap(tester, 'mcp-connect-tab-cursor');
    await _tap(tester, 'mcp-connect-cursor-install');
    expect(h.launched.last, cursorInstallUri(_url));
    expect(_text(tester, 'mcp-connect-cursor-json'), genericMcpConfig(_url));

    await _tap(tester, 'mcp-connect-tab-vscode');
    await _tap(tester, 'mcp-connect-vscode-install');
    expect(h.launched.last, vscodeInstallUri(_url));
    expect(h.launched.last.toString(), startsWith('vscode:mcp/install?'));

    await _tap(tester, 'mcp-connect-tab-other');
    expect(_text(tester, 'mcp-connect-other-json'), genericMcpConfig(_url));
    expect(
      _text(tester, 'mcp-connect-other-remote'),
      'npx -y mcp-remote $_url',
    );
  });

  testWidgets('the single operator whose own request waits is sent to the '
      'installation console', (tester) async {
    await _pump(
      tester,
      identity: _identity(
        eligibility: McpEligibility.requested,
        runtime: false,
      ),
      connections: _connections(eligible: false),
      instance: FakeInstanceRepository(
        state: const InstanceResponsibles(
          you: InstanceRole.owner,
          owners: [InstanceResponsible(name: 'Flo', email: 'f@example.test')],
        ),
      ),
    );
    expect(_key('mcp-connect-step-access-waiting'), findsOneWidget);
    expect(_key('mcp-connect-step-server-todo'), findsOneWidget);
    expect(
      find.textContaining('database administrator to approve'),
      findsOneWidget,
    );
    // Both rows lead to the same console.
    expect(_key('mcp-connect-action-server-openInstallation'), findsOneWidget);
    await _tap(tester, 'mcp-connect-action-access-openInstallation');
    expect(_key('console'), findsOneWidget);
  });

  testWidgets('a member waiting on the operator sees who, and copies a '
      'request to send them', (tester) async {
    final h = await _pump(
      tester,
      identity: _identity(runtime: false),
      instance: FakeInstanceRepository(
        state: const InstanceResponsibles(
          owners: [InstanceResponsible(name: 'Paul', email: 'p@example.test')],
        ),
      ),
    );
    expect(_key('mcp-connect-step-server-waiting'), findsOneWidget);
    expect(find.textContaining("operator: Paul"), findsOneWidget);
    expect(_key('mcp-connect-step-connect-blocked'), findsOneWidget);
    await _tap(tester, 'mcp-connect-action-server-askOperator');
    expect(h.copied.last, contains('switch assistants on'));
  });

  testWidgets('an approval near its end says so', (tester) async {
    await _pump(tester, identity: _identity(left: const Duration(days: 5)));
    expect(find.textContaining('expires in 5 days'), findsOneWidget);
  });

  testWidgets('Google not linked: the row offers the sign-in methods page', (
    tester,
  ) async {
    final identity = _identity()
      ..google = const McpGoogleSignIn(linked: false, session: false);
    await _pump(tester, identity: identity);
    expect(_key('mcp-connect-step-google-todo'), findsOneWidget);
    expect(_key('mcp-connect-step-identity-blocked'), findsOneWidget);
    await _tap(tester, 'mcp-connect-action-google-linkGoogle');
    expect(_key('linked'), findsOneWidget);
  });

  testWidgets('the test waits for a call newer than the last one', (
    tester,
  ) async {
    final connections = _connections();
    final before = kTestNow.toUtc().subtract(const Duration(hours: 2));
    connections.usage.add(
      McpClientUsage(
        clientId: 'c1',
        clientName: 'Claude',
        today: McpUsageCounts.zero,
        lastUsedAt: before,
      ),
    );
    await _pump(tester, connections: connections);
    expect(_key('mcp-connect-last-call'), findsOneWidget);

    await _tap(tester, 'mcp-connect-test');
    expect(_key('mcp-connect-test-waiting'), findsOneWidget);
    expect(
      _text(tester, 'mcp-connect-test-prompt'),
      'Using DesKilo, what are my bookings this week?',
    );

    // The same call again is not a new one.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(_key('mcp-connect-test-waiting'), findsOneWidget);

    connections.usage
      ..clear()
      ..add(
        McpClientUsage(
          clientId: 'c1',
          clientName: 'Claude',
          today: const McpUsageCounts(requests: 1),
          lastUsedAt: before.add(const Duration(hours: 1)),
        ),
      );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_key('mcp-connect-test-reached'), findsOneWidget);
    expect(find.textContaining('Claude reached DesKilo'), findsOneWidget);
  });

  testWidgets('the test gives up and says what to check', (tester) async {
    await _pump(tester);
    await _tap(tester, 'mcp-connect-test');
    for (var i = 0; i < 36; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(_key('mcp-connect-test-timeout'), findsOneWidget);
  });

  group('two workspaces on one installation', () {
    FakeWorkspaceRepository twoSpaces({required bool enabledFirst}) {
      final repo = FakeWorkspaceRepository.withWorkspace(
        featureFlags: const {'mcpAccess': true},
      );
      final other = repo.workspaces.first.copyWith(
        id: 'ws-2',
        name: 'Second Space',
        featureFlags: const {},
      );
      if (enabledFirst) {
        repo.workspaces.add(other);
      } else {
        repo
          ..workspaces.insert(0, other)
          ..serverDefaultWorkspaceId = 'ws-2';
      }
      return repo;
    }

    testWidgets('a member sees each workspace in its own state: one ready, '
        'one off, and is offered to switch to the one that is off', (
      tester,
    ) async {
      await _pump(tester, workspace: twoSpaces(enabledFirst: true));
      expect(_key('mcp-connect-ws-ws-1-ready'), findsOneWidget);
      expect(_key('mcp-connect-ws-ws-2-off'), findsOneWidget);
      expect(find.text('Test Space'), findsOneWidget);
      expect(find.text('Second Space'), findsOneWidget);
      // The selected, enabled workspace needs nothing; the other one is
      // reached by switching, never by asking the operator.
      expect(_key('mcp-connect-ws-ws-1-setup'), findsNothing);
      expect(_key('mcp-connect-ws-ws-1-switch'), findsNothing);
      expect(_key('mcp-connect-ws-ws-2-switch'), findsOneWidget);
      expect(_key('mcp-connect-step-server-done'), findsOneWidget);
      expect(_key('mcp-connect-step-workspace-done'), findsOneWidget);
    });

    testWidgets('the manager of the selected workspace, where assistants are '
        'off, turns them on from setup — no operator step', (tester) async {
      await _pump(
        tester,
        workspace: twoSpaces(enabledFirst: false),
        permissions: const {WorkspacePermission.manageIntegrations},
        featureOn: false,
      );
      // The selected workspace's own row in the checklist says the same.
      expect(_key('mcp-connect-step-workspace-todo'), findsOneWidget);
      expect(_key('mcp-connect-ws-ws-2-off'), findsOneWidget);
      expect(_key('mcp-connect-ws-ws-1-ready'), findsOneWidget);
      expect(_key('mcp-connect-ws-ws-1-switch'), findsNothing);
      await _tap(tester, 'mcp-connect-ws-ws-2-setup');
      expect(_key('setup'), findsOneWidget);
    });
  });

  testWidgets('rendered in French', (tester) async {
    await _pump(tester, locale: const Locale('fr'));
    expect(find.text('Connecter un assistant'), findsOneWidget);
    expect(find.text('Avant de connecter'), findsOneWidget);
  });
}
