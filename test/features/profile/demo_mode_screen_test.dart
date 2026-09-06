// SPDX-License-Identifier: 0BSD
//
// #970 — with demo mode on, the directory still prints the real names
// and the blur covers them; the switch persists; the personal-information
// form stays editable.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_blur.dart';
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
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace()
          ..memberNames = {'member-1': 'Flo'},
        demoMode: store,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(demoSensitive.clear);

  testWidgets('on: the directory prints the real name under a blur',
      (tester) async {
    await _pump(tester, InMemoryDemoModeStore(value: 'on'));
    await openMembersTab(tester);
    expect(find.text('Flo'), findsWidgets, reason: 'nothing hidden');
    expect(demoSensitive.matches('Flo'), isTrue, reason: 'the names provider registered it');
    final flo = tester.getRect(find.text('Flo').first);
    expect(DemoBlurLayer.debugRects.any((r) => r.contains(flo.center)), isTrue,
        reason: 'the blur covers the name');
  });

  testWidgets('off: the switch is there and turning it on persists',
      (tester) async {
    final store = InMemoryDemoModeStore();
    await _pump(tester, store);
    expect(DemoBlurLayer.debugRects, isEmpty);
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

  testWidgets('on: the personal-information form still opens with its fields',
      (tester) async {
    await _pump(tester, InMemoryDemoModeStore(value: 'on'));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings-personal-info'));
    await tester.scrollUntilVisible(tile, 80,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(tile) + const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets, reason: 'editable, blurred');
  });
}
