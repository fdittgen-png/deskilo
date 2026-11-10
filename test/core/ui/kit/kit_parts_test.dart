// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- what the kit's parts do: a status's tint comes from the
// ambient scheme, a split bar draws no part for nothing, a legend line and a
// chip report their choice, a select line toggles as a whole, and the first
// "To do" entry is the filled one.
import 'package:deskilo/core/ui/kit/filter_chips.dart';
import 'package:deskilo/core/ui/kit/select_row.dart';
import 'package:deskilo/core/ui/kit/split_bar.dart';
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/core/ui/kit/todo_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../../../ux/experience_guards.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    pumpApp(tester, Scaffold(body: child));

void main() {
  test('a status takes its tint from the scheme it is drawn in', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    expect(statusColorsOf(scheme, StatusTone.due), (
      scheme.errorContainer,
      scheme.onErrorContainer,
    ));
    expect(statusColorsOf(scheme, StatusTone.info), (
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
    ));
  });

  testWidgets('a split bar draws only the parts that hold something', (
    tester,
  ) async {
    await _pump(
      tester,
      const SplitBar(
        parts: [
          (weight: 3, color: Colors.grey),
          (weight: 0, color: Colors.blue),
          (weight: 1, color: Colors.red),
        ],
      ),
    );
    expect(find.byType(DecoratedBox), findsNWidgets(2));
  });

  testWidgets('a chip and a legend line report their choice', (tester) async {
    String? chosen;
    var legend = 0;
    await _pump(
      tester,
      Column(
        children: [
          FilterChips(
            options: const [
              (value: 'a', label: 'Open', key: ValueKey('c-a')),
              (value: 'b', label: 'Paid', key: ValueKey('c-b')),
            ],
            selected: 'a',
            onSelected: (v) => chosen = v,
          ),
          LegendToggle(
            key: const ValueKey('legend'),
            color: Colors.red,
            label: 'Overdue',
            caption: '8 invoices',
            value: '1,761.00',
            selected: false,
            onTap: () => legend++,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('c-b')));
    await tester.tap(find.byKey(const ValueKey('legend')));
    expect(chosen, 'b');
    expect(legend, 1);
  });

  testWidgets('a select line toggles from anywhere on it', (tester) async {
    bool? value;
    await _pump(
      tester,
      SelectRow(
        selected: false,
        onChanged: (v) => value = v,
        title: 'Atelier Nord',
        caption: const Text('Flexible desk'),
        amount: 'CHF 480.00',
      ),
    );
    await tester.tap(find.text('CHF 480.00'));
    expect(value, isTrue);
  });

  testWidgets('the first To do entry is filled, the others tonal', (
    tester,
  ) async {
    Widget row({required bool primary}) => TodoRow(
      icon: Icons.notifications_outlined,
      title: 'Send reminders',
      caption: '7 invoices',
      buttonLabel: 'Review',
      buttonKey: ValueKey('t-$primary'),
      primary: primary,
      onPressed: () {},
    );
    await _pump(
      tester,
      Column(children: [row(primary: true), row(primary: false)]),
    );
    expect(visibleFilledButtons(), 1);
  });
}
