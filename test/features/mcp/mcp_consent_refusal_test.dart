// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — a refused connection says why and what to do. The sentences the
// consent functions raise (0276, 0342) and Auth's "not found" become one
// explanation each; anything else stays generic. Approving with an
// assistant the operator has not approved used to show nothing at all;
// it now names the cause and who lifts it. A request that can no longer be
// loaded says it expired instead of "could not be loaded".
import 'package:deskilo/core/demo/data/instance_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:deskilo/features/mcp/presentation/mcp_consent_refusal.dart';
import 'package:deskilo/features/mcp/presentation/mcp_consent_screen.dart';
import 'package:deskilo/features/workspace/domain/instance_responsibles.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';

const _auth = 'authz-0002-abcdef';
const _ws = 'ws-1';

class _Refusing extends FakeMcpConnectionRepository {
  _Refusing({this.onPrepare, this.onLoad})
    : super(
        request: const AuthorizationRequest(
          authorizationId: _auth,
          clientId: 'claude-code',
          clientName: 'Claude Code',
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

  final Object? onPrepare;
  final Object? onLoad;

  @override
  Future<AuthorizationRequest> authorization(String authorizationId) async {
    if (onLoad case final e?) throw e;
    return super.authorization(authorizationId);
  }

  @override
  Future<void> prepare(
    String clientId,
    String authorizationId,
    Map<String, List<String>> scopes, {
    Map<String, List<String>> optionalFields = const {},
  }) async {
    if (onPrepare case final e?) throw e;
    return super.prepare(
      clientId,
      authorizationId,
      scopes,
      optionalFields: optionalFields,
    );
  }
}

Future<void> _pump(WidgetTester tester, _Refusing repo) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          mcpConnections: repo,
          instance: FakeInstanceRepository(
            state: const InstanceResponsibles(
              owners: [
                InstanceResponsible(name: 'Paul', email: 'p@example.test'),
              ],
            ),
          ),
        ),
      ],
      retry: (_, _) => null,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: McpConsentScreen(authorizationId: _auth),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  group('the classifier', () {
    PostgrestException db(String m) => PostgrestException(message: m);

    test('each sentence the server raises maps to its own refusal', () {
      expect(
        mcpConsentRefusal(
          db('this assistant is not approved on this instance'),
        ),
        McpConsentRefusal.clientNotApproved,
      );
      expect(
        mcpConsentRefusal(db('this database has not approved MCP for you yet')),
        McpConsentRefusal.notEligible,
      );
      expect(
        mcpConsentRefusal(
          db(
            'link your Google account first: assistants use your Google '
            'sign-in',
          ),
        ),
        McpConsentRefusal.linkGoogle,
      );
      expect(
        mcpConsentRefusal(db('sign in with Google to connect an assistant')),
        McpConsentRefusal.signInWithGoogle,
      );
      expect(
        mcpConsentRefusal(db('no verified identity binding')),
        McpConsentRefusal.noIdentity,
      );
      expect(
        mcpConsentRefusal(db('workspace ws-9 cannot be offered')),
        McpConsentRefusal.offerChanged,
      );
      expect(
        mcpConsentRefusal(
          db(
            'operation create_reservation is not available '
            'there',
          ),
        ),
        McpConsentRefusal.offerChanged,
      );
      expect(
        mcpConsentRefusal(const AuthException('authorization not found')),
        McpConsentRefusal.requestExpired,
      );
    });

    test('anything else is not guessed at', () {
      expect(mcpConsentRefusal(db('connection reset')), isNull);
      expect(mcpConsentRefusal(StateError('boom')), isNull);
    });
  });

  group('the screen', () {
    testWidgets('an assistant the operator has not approved: the refusal '
        'says so and names who lifts it', (tester) async {
      final repo = _Refusing(
        onPrepare: const PostgrestException(
          message: 'this assistant is not approved on this instance',
        ),
      );
      await _pump(tester, repo);
      await tester.tap(_key('mcp-consent-ws-toggle-$_ws'));
      await tester.pumpAndSettle();
      await tester.tap(_key('mcp-consent-approve'));
      await tester.pumpAndSettle();
      expect(_key('mcp-consent-refused-clientNotApproved'), findsOneWidget);
      expect(
        find.textContaining('not approved on this server'),
        findsOneWidget,
      );
      expect(find.textContaining('Paul'), findsOneWidget);
      expect(repo.calls, isNot(contains('approve')));
    });

    testWidgets('an unexplained failure still says something', (tester) async {
      final repo = _Refusing(onPrepare: StateError('boom'));
      await _pump(tester, repo);
      await tester.tap(_key('mcp-consent-ws-toggle-$_ws'));
      await tester.pumpAndSettle();
      await tester.tap(_key('mcp-consent-approve'));
      await tester.pumpAndSettle();
      expect(_key('mcp-consent-failed'), findsOneWidget);
    });

    testWidgets('a request that cannot be loaded because it expired says so', (
      tester,
    ) async {
      await _pump(
        tester,
        _Refusing(onLoad: const AuthException('authorization not found')),
      );
      expect(_key('mcp-consent-refused-requestExpired'), findsOneWidget);
      expect(_key('mcp-consent-unavailable'), findsNothing);
    });
  });
}
