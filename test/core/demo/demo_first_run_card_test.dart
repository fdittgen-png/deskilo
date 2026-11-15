// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4009 — the Demo's first-run card says the Demo is one organisation,
// Atelier du Marché with houses in six countries (the head's France, Switzerland, Germany, the United Kingdom, Italy, the United States) and four currencies, and
// offers every house to enter: the head first, then the houses in Me's order,
// each with its country and currency; the Berlin practice is offered apart,
// as a business of its own. Entering a house from the card lands in it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _card = ValueKey('demo-setup-card');

Future<ProviderContainer> _open(WidgetTester tester, Size size,
    {double textScale = 1}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final outer = ProviderContainer();
  addTearDown(outer.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: outer,
      child: const DemoWorkspace(child: DeskiloApp()),
    ),
  );
  await tester.pumpAndSettle();
  final demo = ProviderScope.containerOf(
    tester.element(find.byType(DeskiloApp)),
  );
  demo.read(routerProvider).go('/setup');
  await tester.pumpAndSettle();
  return demo;
}

List<String> _houseIds(WidgetTester tester) => [
  for (final w in tester.widgetList(
    find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('demo-house-'),
    ),
  ))
    (w.key! as ValueKey<String>).value.substring('demo-house-'.length),
];

String _text(WidgetTester tester, Finder within) => tester
    .widgetList<Text>(
      find.descendant(of: within, matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('at ${width.toInt()} px the card says the Demo is one '
        'organisation and lists its houses in order, each with its country '
        'and currency, and the practice apart', (tester) async {
      await _open(tester, Size(width, 3200));
      final text = _text(tester, find.byKey(_card));
      expect(text, contains('one organisation'));
      expect(text, contains('Atelier du Marché'));
      expect(text, contains('6 countries'));
      expect(text, contains('4 currencies'));
      expect(
        _houseIds(tester),
        ['ws-1', 'ws-5', 'ws-2', 'ws-3', 'ws-6', 'ws-4'],
        reason: 'the head first, then Switzerland, Germany, United Kingdom, '
            'Italy, United States',
      );
      for (final line in [
        'France · EUR',
        'Switzerland · CHF',
        'Germany · EUR',
        'United Kingdom · GBP',
        'Italy · EUR',
        'United States · USD',
      ]) {
        expect(text, contains(line));
      }
      expect(
        find.byKey(const ValueKey('demo-house-ws-7')),
        findsNothing,
        reason: 'the practice is not a house',
      );
      expect(find.byKey(const ValueKey('demo-organisation-outside')),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('demo-organisation-outside')),
          matching: find.textContaining('Lindner Beratung'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a tap on London enters London, and a tap on the practice '
      'enters the practice', (tester) async {
    final demo = await _open(tester, const Size(900, 3200));
    await tester.tap(find.byKey(const ValueKey('demo-house-ws-3')));
    await tester.pumpAndSettle();
    expect(demo.read(currentWorkspaceProvider).value?.id, 'ws-3');
    demo.read(routerProvider).go('/setup');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-organisation-outside')));
    await tester.pumpAndSettle();
    expect(demo.read(currentWorkspaceProvider).value?.id, 'ws-7');
  });

  testWidgets('at 320 px with 1.3 text no line is cut', (tester) async {
    await _open(tester, const Size(320, 3600), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(_houseIds(tester), hasLength(6));
    for (final id in _houseIds(tester)) {
      final box = tester.getRect(find.byKey(ValueKey('demo-house-$id')));
      expect(box.left, greaterThanOrEqualTo(0), reason: id);
      expect(box.right, lessThanOrEqualTo(320), reason: id);
    }
    final card = tester.getRect(find.byKey(_card));
    expect(card.right, lessThanOrEqualTo(320));
  });
}
