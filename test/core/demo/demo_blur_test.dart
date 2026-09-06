// SPDX-License-Identifier: 0BSD
//
// #970 — the blur layer: with demo mode on it covers exactly the
// paragraphs and text fields that carry a registered personal string,
// the text stays in the tree, and off it covers nothing.
import 'package:deskilo/core/demo/demo_blur.dart';
import 'package:deskilo/core/demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';

Future<void> _pump(WidgetTester tester, {required bool on}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoModeStoreProvider
            .overrideWithValue(InMemoryDemoModeStore(value: on ? 'on' : null)),
      ],
      child: MaterialApp(
        builder: (context, child) => DemoBlurLayer(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const Text('Guilhem MARTIN', key: ValueKey('name')),
              const Text('Total 100,00 €', key: ValueKey('amount')),
              TextField(
                key: const ValueKey('field'),
                controller: TextEditingController(text: 'g@kaloa.fr'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    demoSensitive.clear();
    demoSensitive.addAll(['Guilhem MARTIN', 'g@kaloa.fr']);
  });

  testWidgets('on: the name and the field are covered, the amount is not, '
      'and the real text is still there', (tester) async {
    await _pump(tester, on: true);
    final rects = DemoBlurLayer.debugRects;
    expect(rects, hasLength(2));
    final name = tester.getRect(find.byKey(const ValueKey('name')));
    final amount = tester.getRect(find.byKey(const ValueKey('amount')));
    expect(rects.any((r) => r.contains(name.center)), isTrue);
    expect(rects.any((r) => r.contains(amount.center)), isFalse);
    expect(find.text('Guilhem MARTIN'), findsOneWidget, reason: 'nothing hidden');
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('off: no blur at all', (tester) async {
    await _pump(tester, on: false);
    expect(DemoBlurLayer.debugRects, isEmpty);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
