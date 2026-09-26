// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1615 — connecting an assistant: nothing is preselected, only offered
// workspaces and operations can be chosen, Connect needs a choice, the
// three steps run in order (the database records, Auth approves, the
// database finalises), an unfinalised approval is never reported as
// connected, Deny tells Auth no, and a person the database has not
// approved is told so and can ask.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/mcp/application/connect_assistant.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _auth = 'authz-0001-abcdef';
const _a = '00000000-0000-4000-8000-0000000000aa';
const _b = '00000000-0000-4000-8000-0000000000bb';

FakeMcpConnectionRepository repo({bool eligible = true}) =>
    FakeMcpConnectionRepository(
      request: const AuthorizationRequest(
        authorizationId: _auth,
        clientId: 'claude-desktop',
        clientName: 'Test assistant',
      ),
      consent: ConsentOptions(
        eligible: eligible,
        workspaces: const [
          ConsentWorkspace(
            id: _a,
            name: 'Kraftwerk',
            operations: ['get_availability', 'create_reservation'],
          ),
          ConsentWorkspace(
            id: _b,
            name: 'Atelier',
            operations: ['list_my_invoices'],
          ),
        ],
      ),
    );

Future<void> pump(WidgetTester tester, FakeMcpConnectionRepository r) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(mcpConnections: r),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/oauth/consent?authorization_id=$_auth'),
  );
  await tester.pumpAndSettle();
}

FilledButton approve(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey('mcp-consent-approve')),
);

void main() {
  group('the DTOs', () {
    test(
      'an unknown eligibility is not eligible, and malformed rows are dropped',
      () {
        final o = ConsentOptions.fromJson({
          'eligibility': 'pending',
          'workspaces': [
            {
              'workspace_id': _a,
              'name': 'K',
              'operations': ['check_in'],
            },
            {'name': 'no id'},
          ],
        });
        expect(o.eligible, isFalse);
        expect(o.workspaces.single.operations, ['check_in']);
        expect(ConsentOptions.fromJson(null).eligible, isFalse);
        expect(
          McpConnectionInfo.listFromJson([
            {'client_id': 'c', 'client_name': null, 'workspaces': <Object>[]},
          ]).single.clientName,
          'c',
        );
      },
    );
  });

  group('the command', () {
    test(
      'records, approves, then finalises; an empty choice sends nothing',
      () async {
        final r = repo();
        final connect = ConnectAssistant(r, () async {});
        final none = await connect.connect(r.request!, {_a: <String>[]});
        expect(none.outcome, ConnectOutcome.nothingChosen);
        expect(r.calls, isEmpty);

        final done = await connect.connect(r.request!, {
          _a: ['get_availability'],
          _b: [],
        });
        expect(done.outcome, ConnectOutcome.connected);
        expect(r.calls, ['prepare', 'approve', 'finalize']);
        expect(r.prepared.single, {
          _a: ['get_availability'],
        }, reason: 'an unticked workspace is not sent');
      },
    );

    test('an approval whose finalisation failed is not "connected"', () async {
      final r = repo()..failFinalize = true;
      final result = await ConnectAssistant(r, () async {}).connect(
        r.request!,
        {
          _a: ['get_availability'],
        },
      );
      expect(result.outcome, ConnectOutcome.approvedNotFinalized);
    });
  });

  group('the screen', () {
    testWidgets('nothing is preselected, and Connect needs a choice', (
      tester,
    ) async {
      await pump(tester, repo());
      expect(
        find.text('Test assistant asks to act for you in Deskilo.'),
        findsOneWidget,
      );
      expect(find.text('Kraftwerk'), findsOneWidget);
      expect(find.text('Atelier'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mcp-consent-op-$_a-get_availability')),
        findsNothing,
      );
      expect(approve(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('mcp-consent-ws-toggle-$_a')));
      await tester.pumpAndSettle();
      expect(find.text('See free places'), findsOneWidget);
      expect(find.text('Book a place for you'), findsOneWidget);
      expect(approve(tester).onPressed, isNotNull);

      // Unticking every operation of the only workspace disables Connect.
      await tester.tap(
        find.byKey(const ValueKey('mcp-consent-op-$_a-get_availability')),
      );
      await tester.tap(
        find.byKey(const ValueKey('mcp-consent-op-$_a-create_reservation')),
      );
      await tester.pumpAndSettle();
      expect(approve(tester).onPressed, isNull);
    });

    testWidgets('Connect sends exactly the chosen subset, in order', (
      tester,
    ) async {
      final r = repo();
      await pump(tester, r);
      await tester.tap(find.byKey(const ValueKey('mcp-consent-ws-toggle-$_a')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('mcp-consent-op-$_a-create_reservation')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mcp-consent-approve')));
      await tester.pumpAndSettle();
      expect(r.calls, ['prepare', 'approve', 'finalize']);
      expect(r.prepared.single, {
        _a: ['get_availability'],
      });
      expect(
        find.byKey(const ValueKey('mcp-consent-connected')),
        findsOneWidget,
      );
    });

    testWidgets('an unfinalised approval says so', (tester) async {
      final r = repo()..failFinalize = true;
      await pump(tester, r);
      await tester.tap(find.byKey(const ValueKey('mcp-consent-ws-toggle-$_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mcp-consent-approve')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mcp-consent-partial')), findsOneWidget);
      expect(find.byKey(const ValueKey('mcp-consent-connected')), findsNothing);
    });

    testWidgets('Deny tells Auth no and records nothing', (tester) async {
      final r = repo();
      await pump(tester, r);
      await tester.tap(find.byKey(const ValueKey('mcp-consent-deny')));
      await tester.pumpAndSettle();
      expect(r.calls, ['deny']);
      expect(find.byKey(const ValueKey('mcp-consent-denied')), findsOneWidget);
    });

    testWidgets(
      'a person the database has not approved can ask, and cannot connect',
      (tester) async {
        await pump(tester, repo(eligible: false));
        expect(
          find.byKey(const ValueKey('mcp-consent-not-eligible')),
          findsOneWidget,
        );
        expect(find.text('Kraftwerk'), findsNothing);
        expect(approve(tester).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey('mcp-consent-request-eligibility')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mcp-consent-requested')),
          findsOneWidget,
        );
      },
    );
  });
}
