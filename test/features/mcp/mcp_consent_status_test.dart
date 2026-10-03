// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — the consent page reads the client's approval first (0354). An
// assistant the operator has not approved never reaches Auth's
// authorization API: the page names the cause, who decides (or "you", with
// the console), where the answer would go, and offers Deny only. An
// approved client shows its family and redirect host and connects as
// before. The connect page gives assistants the endpoint the installation
// publishes.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/core/demo/data/mcp_onboarding_repository.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:deskilo/features/mcp/domain/mcp_onboarding.dart';
import 'package:deskilo/features/mcp/presentation/connect_assistant_screen.dart';
import 'package:deskilo/features/mcp/presentation/mcp_consent_screen.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _auth = 'authz-0003-abcdef';
const _ws = 'ws-1';

class _Recording extends FakeMcpConnectionRepository {
  _Recording()
    : super(
        request: const AuthorizationRequest(
          authorizationId: _auth,
          clientId: 'dcr-1',
          clientName: 'Claude',
        ),
        consent: const ConsentOptions(
          eligible: true,
          workspaces: [
            ConsentWorkspace(
              id: _ws,
              name: 'Test Space',
              operations: ['get_availability'],
            ),
          ],
        ),
      );

  @override
  Future<AuthorizationRequest> authorization(String authorizationId) {
    calls.add('authorization');
    return super.authorization(authorizationId);
  }
}

ConsentStatus _status(
  McpClientApproval approval, {
  ConsentDecider? decider,
  String? family,
}) => ConsentStatus(
  eligibility: 'eligible',
  client: ConsentClient(
    clientId: 'dcr-1',
    name: 'Claude',
    status: approval,
    redirectHost: 'claude.ai',
    family: family,
  ),
  decider: decider,
);

Future<void> _pump(
  WidgetTester tester, {
  required _Recording connections,
  required FakeMcpOnboardingRepository onboarding,
  Widget home = const McpConsentScreen(authorizationId: _auth),
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/installation/assistants',
        builder: (_, _) => const Text('console', key: ValueKey('console')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          mcpConnections: connections,
          mcpOnboarding: onboarding,
        ),
        enabledFeaturesSyncProvider.overrideWithValue(const {
          WorkspaceFeature.mcpAccess,
        }),
        bootedBackendUrlProvider.overrideWithValue('https://abc.supabase.co'),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('a waiting assistant: the cause, who decides, Deny only — '
      'and Auth is never asked for the authorization', (tester) async {
    final connections = _Recording();
    await _pump(
      tester,
      connections: connections,
      onboarding: FakeMcpOnboardingRepository(
        status: _status(
          McpClientApproval.waiting,
          decider: const ConsentDecider(
            kind: McpDeciderKind.operator,
            displayName: 'Paul',
          ),
        ),
      ),
    );
    expect(_key('mcp-consent-client-waiting'), findsOneWidget);
    expect(find.text('Ask Paul to decide.'), findsOneWidget);
    expect(find.text('The answer is sent to claude.ai.'), findsOneWidget);
    expect(_key('mcp-consent-approve'), findsNothing);
    expect(connections.calls, isNot(contains('authorization')));
    await tester.tap(_key('mcp-consent-deny'));
    await tester.pumpAndSettle();
    expect(connections.calls, contains('deny'));
  });

  testWidgets('the operator who decides is sent to the console', (
    tester,
  ) async {
    await _pump(
      tester,
      connections: _Recording(),
      onboarding: FakeMcpOnboardingRepository(
        status: _status(
          McpClientApproval.waiting,
          decider: const ConsentDecider(
            kind: McpDeciderKind.operator,
            displayName: 'Flo',
            me: true,
          ),
        ),
      ),
    );
    expect(_key('mcp-consent-decider-me'), findsOneWidget);
    await tester.tap(_key('mcp-consent-open-console'));
    await tester.pumpAndSettle();
    expect(_key('console'), findsOneWidget);
  });

  testWidgets('a blocked assistant cannot be connected and names nobody', (
    tester,
  ) async {
    await _pump(
      tester,
      connections: _Recording(),
      onboarding: FakeMcpOnboardingRepository(
        status: _status(
          McpClientApproval.blocked,
          decider: const ConsentDecider(kind: McpDeciderKind.operator),
        ),
      ),
    );
    expect(_key('mcp-consent-client-blocked'), findsOneWidget);
    expect(_key('mcp-consent-decider-operator'), findsNothing);
    expect(_key('mcp-consent-approve'), findsNothing);
  });

  testWidgets('an approved assistant shows its family and connects as '
      'before', (tester) async {
    final connections = _Recording();
    await _pump(
      tester,
      connections: connections,
      onboarding: FakeMcpOnboardingRepository(
        status: _status(McpClientApproval.approved, family: 'claude'),
      ),
    );
    expect(_key('mcp-consent-family-claude'), findsOneWidget);
    expect(_key('mcp-consent-redirect-host'), findsOneWidget);
    await tester.tap(_key('mcp-consent-ws-toggle-$_ws'));
    await tester.pumpAndSettle();
    await tester.tap(_key('mcp-consent-approve'));
    await tester.pumpAndSettle();
    expect(connections.calls, containsAllInOrder(['prepare', 'approve']));
  });

  testWidgets('no client in the answer (an older server) keeps the older '
      'path', (tester) async {
    final connections = _Recording();
    await _pump(
      tester,
      connections: connections,
      onboarding: FakeMcpOnboardingRepository(),
    );
    expect(connections.calls, contains('authorization'));
    expect(_key('mcp-consent-approve'), findsOneWidget);
  });

  testWidgets('the connect page gives the endpoint the installation '
      'publishes', (tester) async {
    await _pump(
      tester,
      connections: _Recording(),
      onboarding: FakeMcpOnboardingRepository(
        published: const McpEndpointInfo(
          resource: 'https://mcp.example.test/mcp',
          source: McpEndpointSource.configured,
        ),
      ),
      home: const ConnectAssistantScreen(),
    );
    expect(
      tester.widget<SelectableText>(_key('mcp-connect-url')).data,
      'https://mcp.example.test/mcp',
    );
  });
}
