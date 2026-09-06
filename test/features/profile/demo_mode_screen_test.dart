// SPDX-License-Identifier: 0BSD
//
// #970 — with demo mode on, the directory shows invented names, the
// settings switch persists, and the personal-information form refuses
// to open.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<void> _pump(WidgetTester tester, InMemoryDemoModeStore store) async {
  tester.view.physicalSize = const Size(800, 3100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace()
            ..memberNames = {'member-1': 'Flo'},
          demoMode: store,
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on: the directory shows an invented name instead of the real '
      'one', (tester) async {
    await _pump(tester, InMemoryDemoModeStore(value: 'on'));
    await openMembersTab(tester);
    expect(find.text('Flo'), findsNothing);
    expect(find.text(demoName('Flo')), findsWidgets);
  });

  testWidgets('off: the switch is there and turning it on persists',
      (tester) async {
    final store = InMemoryDemoModeStore();
    await _pump(tester, store);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings-demo-mode'));
    await tester.scrollUntilVisible(tile, 80,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(store.value, 'on');
  });

  testWidgets('on: the personal-information form is replaced by the notice',
      (tester) async {
    await _pump(tester, InMemoryDemoModeStore(value: 'on'));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings-personal-info'));
    await tester.scrollUntilVisible(tile, 80,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    // The tile's centre sits on its help dot; tap the leading edge.
    await tester.tapAt(tester.getTopLeft(tile) + const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('demo-mode-edit-blocked')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
