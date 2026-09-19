// SPDX-License-Identifier: 0BSD
//
// #1379 — walking in, and walking out.
//
// The demonstration space is not a different app: entering it builds the
// SAME `DeskiloApp` inside a container whose repositories are the
// fixture's. These tests hold that to the two promises the entry makes —
// that no account is needed, and that leaving forgets what happened.
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_entry_sheet.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the offer explains the space before anybody walks into it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: DemoEntryButton())),
        ),
      ),
    );

    expect(container.read(demoEntryProvider), isFalse);
    await tester.tap(find.byKey(DemoEntryButton.buttonKey));
    await tester.pumpAndSettle();

    // The three things somebody has to know before they start clicking.
    final sheet = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(sheet, contains('made up'));
    expect(sheet, contains('reaches a real workspace'));
    expect(sheet, contains('no account is needed'));
    expect(
      container.read(demoEntryProvider),
      isFalse,
      reason: 'reading the explanation is not consenting to it',
    );

    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await tester.pumpAndSettle();
    expect(container.read(demoEntryProvider), isTrue);
  });

  testWidgets('leaving forgets the session, so the next visit is canonical', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(demoEntryProvider.notifier).enter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: SizedBox())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A visitor changes the space and looks at it from elsewhere.
    final fixture = container.read(demoSessionControllerProvider).fixture;
    await fixture.floorPlan.createLevel('ws-1', 'Mezzanine', 9);
    container.read(demoSessionControllerProvider.notifier).viewAs(
          DemoPersona.member,
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DemoControls.leaveKey));
    await tester.pumpAndSettle();

    expect(container.read(demoEntryProvider), isFalse);
    final next = container.read(demoSessionControllerProvider);
    expect(next.persona, initialDemoPersona);
    final levels = await next.fixture.floorPlan.fetchLevels('ws-1');
    expect(
      levels.map((l) => l.name),
      isNot(contains('Mezzanine')),
      reason: 'the next visit starts from the canonical dataset',
    );
  });

  testWidgets('live mode has no demonstration bar at all', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DemoControls(child: Scaffold(body: Text('the real app'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('the real app'), findsOneWidget);
    expect(find.byKey(DemoControls.resetKey), findsNothing);
    expect(find.byKey(DemoControls.viewAsKey), findsNothing);
  });
}
