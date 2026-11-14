// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3962 — the real assistants page and the real confirmation page, on the
// Demo: the connected assistant and its operations, the waiting request
// answered by a press, the connection revoked by a press. #3978 — the
// waiting request is found on the assistants page and answered from there.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/mcp/presentation/assistants_screen.dart';
import 'package:deskilo/features/mcp/presentation/mcp_confirmation_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/demo_assistant_journeys.dart';
import '../../helpers/pump_app.dart';

Future<DemoFixture> _open(
  WidgetTester tester,
  Widget? page, {
  GoRouter? router,
}) async {
  final fixture = DemoFixture.build()..becomePersona(DemoPersona.owner);
  final workspace = fixture.workspaces.workspaces.firstWhere(
    (w) => w.id == 'ws-1',
  );
  await pumpApp(
    tester,
    page,
    router: router,
    size: const Size(420, 1400),
    overrides: [
      ...demoOverrides(fixture),
      currentWorkspaceProvider.overrideWith((ref) async => workspace),
    ],
  );
  ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
      .listen(authStateProvider, (_, _) {});
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  testWidgets('the page lists the connected assistant and revokes it', (
    tester,
  ) async {
    await _open(tester, const AssistantsScreen());
    expect(
      find.byKey(const ValueKey('mcp-eligibility-eligible')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mcp-connection-$assistantId')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mcp-disconnect-$assistantId')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // #3978 — the requests above push the button down: bring it fully in.
    await tester.ensureVisible(
      find.byKey(const ValueKey('mcp-disconnect-$assistantId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp-disconnect-$assistantId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp-disconnect-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mcp-connection-$assistantId')),
      findsNothing,
    );
  });

  testWidgets('the waiting request is found on the page, confirmed from '
      'there, and leaves the waiting section', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AssistantsScreen()),
        GoRoute(
          path: '/mcp/confirm/:id',
          builder: (_, state) => McpConfirmationScreen(
            confirmationId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
    final fixture = await _open(tester, null, router: router);
    const waiting = ValueKey('mcp-request-waiting-$waitingConfirmation');
    expect(find.byKey(waiting), findsOneWidget);
    for (final id in [confirmedConfirmation, refusedConfirmation]) {
      expect(
        find.byKey(ValueKey('mcp-request-answered-$id')),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.byKey(const ValueKey('mcp-request-open-$waitingConfirmation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp-confirm-accept')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mcp-confirm-status-acknowledged')),
      findsOneWidget,
    );
    expect(eventOf(fixture, roomRequestEvent).status, EventStatus.confirmed);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(waiting), findsNothing);
    expect(
      find.byKey(
        const ValueKey('mcp-request-answered-$waitingConfirmation'),
      ),
      findsOneWidget,
    );
  });
}
