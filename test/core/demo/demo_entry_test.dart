// SPDX-License-Identifier: 0BSD
//
// #1379 — walking in, and walking out.
//
// The demonstration space is not a different app: entering it builds the
// SAME `DeskiloApp` inside a container whose repositories are the
// fixture's. These tests hold that to the two promises the entry makes —
// that no account is needed, and that leaving forgets what happened.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_entry_sheet.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/theme/theme_controller.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the device remembered before a visitor ever tapped "Explore".
const Map<String, Object> _realDevice = {
  'default_workspace_id': 'ws-real',
  'active_workspace_id': 'ws-real',
  'backend_supabase_url': 'https://real.example.test',
  'backend_supabase_key': 'real-key',
  'locale_override': 'fr',
  'theme_mode_override': 'dark',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('#1564 — a whole visit: change everything, cycle the '
      'personas, reset, leave — and the device is exactly as it was', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(_realDevice);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(demoEntryProvider.notifier).enter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DemoWorkspace(
          child: MaterialApp(
            home: DemoControls(child: Scaffold(body: SizedBox())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The container `DemoWorkspace` built — the one every screen below
    // it reads, and the one the settings surfaces write through.
    final demo = ProviderScope.containerOf(
      tester.element(find.byType(DemoControls)),
    );
    await demo.read(localeControllerProvider.notifier).set(const Locale('es'));
    await demo.read(themeControllerProvider.notifier).set(ThemeMode.light);
    await demo.read(activeBackendProvider.future);
    await demo.read(activeBackendProvider.notifier).setEndpoint(
          const BackendEndpoint('https://demo.example.test', 'demo-key'),
        );
    await demo.read(activeWorkspaceIdProvider.notifier).select('ws-1');
    await tester.pumpAndSettle();

    // Round the persona ring, then put it back, then walk out.
    for (var i = 0; i < DemoPersona.values.length; i++) {
      await tester.tap(find.byKey(DemoControls.viewAsKey));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(DemoControls.resetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DemoControls.leaveKey));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    for (final entry in _realDevice.entries) {
      expect(
        prefs.get(entry.key),
        entry.value,
        reason: 'the visit changed the real app\'s ${entry.key}. A demo '
            'that edits the device it is demonstrated on is not a demo '
            '(#1564)',
      );
    }
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
