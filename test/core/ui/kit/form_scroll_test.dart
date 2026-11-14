// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3946 — the kit's keyboard order on a form: a form page builds all its
// controls (a lazy list drops those that left the screen, so Tab meets the
// first one again as another stop), the page's policy walks them in the
// order they are built (the reading order sorts rows of unequal height
// twice), a radio group is one Tab stop with the arrows moving inside it,
// the amount field answers Up and Down itself, and the calendar button of
// a date field is no stop of the keyboard.
import 'dart:ui' show CheckedState;

import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/core/ui/kit/form_scroll.dart';
import 'package:deskilo/core/ui/kit/radio_row.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget body) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: FocusTraversalGroup(policy: PageTraversalPolicy(), child: body),
  ),
);

/// The key of the field that has the keyboard.
String? _focused() {
  final context = FocusManager.instance.primaryFocus?.context;
  String? key;
  context?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      key = k.value;
      return false;
    }
    return true;
  });
  return key;
}

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

void main() {
  group('FormScroll', () {
    testWidgets('builds every control, however far the form is scrolled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          FormScroll(
            children: [
              for (var i = 0; i < 40; i++)
                TextField(
                  key: ValueKey('f$i'),
                  decoration: const InputDecoration(labelText: 'x'),
                ),
            ],
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('f39'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('f0')), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('f0'), skipOffstage: false),
        findsOneWidget,
        reason: 'the first field is still built at the end of the form',
      );
    });

    testWidgets('Tab walks the controls in the order they are built, once', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Rows of unequal height: a short field beside a column of three.
      final keys = <String>[];
      Widget field(String k) {
        keys.add(k);
        return TextField(key: ValueKey(k));
      }

      await tester.pumpWidget(
        _host(
          FormScroll(
            children: [
              field('a'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: field('b')),
                  Expanded(
                    child: Column(
                      children: [field('c'), field('d'), field('e')],
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < 12; i++) field('g$i'),
            ],
          ),
        ),
      );
      final walked = <String?>[];
      for (var i = 0; i < keys.length; i++) {
        await _tab(tester);
        walked.add(_focused());
      }
      expect(walked, keys);
      await _tab(tester);
      expect(_focused(), keys.first, reason: 'the cycle closes on the first');
    });
  });

  group('RadioRow', () {
    Widget group(ValueChanged<int?> onChanged, int? value) => _host(
      RadioGroup<int>(
        groupValue: value,
        onChanged: onChanged,
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              RadioRow<int>(
                key: ValueKey('r$i'),
                value: i,
                title: Text('Choice $i'),
              ),
            const TextField(key: ValueKey('after')),
          ],
        ),
      ),
    );

    testWidgets('a group is one stop, and the arrows choose inside it', (
      tester,
    ) async {
      var chosen = 1;
      late StateSetter set;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return group((v) => set(() => chosen = v!), chosen);
          },
        ),
      );
      await _tab(tester);
      expect(_focused(), 'r1', reason: 'Tab enters at the chosen row');
      await _tab(tester);
      expect(_focused(), 'after', reason: 'and leaves after it: one stop');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_focused(), 'r1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(chosen, 2);
      expect(_focused(), 'r2');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(chosen, 1);
    });

    testWidgets('the row names itself and says whether it is chosen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(group((_) {}, 0));
      final node = tester.getSemantics(find.byKey(const ValueKey('r0')));
      expect(node.label, contains('Choice 0'));
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('r1')))
            .flagsCollection
            .isChecked,
        CheckedState.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('a tap anywhere on the row chooses it', (tester) async {
      int? chosen;
      await tester.pumpWidget(group((v) => chosen = v, null));
      await tester.tap(find.text('Choice 2'));
      await tester.pump();
      expect(chosen, 2);
    });
  });

  group('the form kit fields', () {
    testWidgets('the calendar button of a date field is no stop', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              AppDateField(
                key: const ValueKey('d'),
                label: 'Day',
                value: null,
                locale: 'en_GB',
                onChanged: (_) {},
              ),
              const TextField(key: ValueKey('next')),
            ],
          ),
        ),
      );
      await _tab(tester);
      await _tab(tester);
      expect(_focused(), 'next');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      final stops = FocusManager.instance.rootScope.descendants.where(
        (n) =>
            n.canRequestFocus &&
            n.context?.findAncestorWidgetOfExactType<IconButton>() != null,
      );
      expect(stops, isEmpty, reason: 'the button is not focusable at all');
    });

    testWidgets('Up and Down in an amount field take the caret to its edges', (
      tester,
    ) async {
      final c = TextEditingController(text: '12,50');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(
          AppAmountField(
            key: const ValueKey('a'),
            controller: c,
            label: 'Price',
            currency: 'EUR',
            allowNegative: false,
          ),
        ),
      );
      await _tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(c.selection, const TextSelection.collapsed(offset: 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(c.selection, const TextSelection.collapsed(offset: 0));
      expect(tester.takeException(), isNull);
    });
  });
}
