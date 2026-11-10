// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- what the kit's parts do: a status's tint comes from the
// ambient scheme, a split bar draws no part for nothing, a legend line and a
// chip report their choice, a select line toggles as a whole, and the first
// "To do" entry is the filled one.
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:deskilo/core/ui/kit/customer_row.dart';
import 'package:deskilo/core/ui/kit/filter_chips.dart';
import 'package:deskilo/core/ui/kit/kit_card.dart';
import 'package:deskilo/core/ui/kit/result_page.dart';
import 'package:deskilo/core/ui/kit/select_row.dart';
import 'package:deskilo/core/ui/kit/split_bar.dart';
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/core/ui/kit/todo_card.dart';
import 'package:deskilo/core/ui/kit/todo_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../../../ux/experience_guards.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    pumpApp(tester, Scaffold(body: child));

void _noop() {}

void main() {
  test('a status takes its pair from the theme tokens; "info" is never the '
      'colour of "ok"', () {
    for (final (t, scheme) in [
      (PersonalTheme.light, ColorScheme.fromSeed(seedColor: Colors.brown)),
      (
        PersonalTheme.dark,
        ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.dark,
        ),
      ),
    ]) {
      (Color, Color) of(StatusTone tone) =>
          statusColorsOf(t, tone, scheme: scheme);
      expect(of(StatusTone.info), (t.infoTint, t.info));
      expect(of(StatusTone.due), (t.dangerTint, t.danger));
      expect(of(StatusTone.info).$2, isNot(of(StatusTone.ok).$2));
      // Neutral is the theme's own quiet pair, never a tinted meaning.
      expect(of(StatusTone.neutral), (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ));
    }
  });

  testWidgets('the quiet line replaces the To do entries, never sits under '
      'them; the badge counts what waits', (tester) async {
    Widget card(List<Widget> rows, {int? count}) => TodoCard(
      title: 'To do',
      rows: rows,
      count: count,
      quiet: const QuietLine('You are all caught up.'),
    );
    await _pump(tester, card(const []));
    expect(find.text('You are all caught up.'), findsOneWidget);
    await _pump(tester, card(const [Text('Invoice October')], count: 7));
    expect(find.text('You are all caught up.'), findsNothing);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('the result shows a check when something was done, the alert '
      'when nothing was', (tester) async {
    Widget result({required bool something}) => ResultPage(
      title: 'Result',
      subtitle: '',
      done: [
        if (something) (title: 'Atelier Nord', detail: '', outcome: 'Issued'),
      ],
      notDone: const [
        (title: 'Kontor', detail: 'Address missing', outcome: ''),
      ],
      notDoneHeading: 'Not done',
      staysNote: '',
      doneLabel: 'Done',
      onDone: () {},
    );
    await _pump(tester, result(something: true));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await _pump(tester, result(something: false));
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('on a wide window a customer line is a table row whose columns '
      'sit under the header', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          CustomerHeader(
            customer: 'Customer',
            invoices: 'Invoices',
            oldest: 'Oldest',
            owes: 'Owes',
          ),
          CustomerRow(
            name: 'SASU KaloA',
            caption: Text('2 invoices'),
            invoices: '2',
            oldest: Text('50 days late'),
            owes: ['CHF 200.00'],
            onTap: _noop,
            wide: true,
          ),
        ],
      ),
    );
    expect(
      tester.getTopLeft(find.text('2')).dx,
      tester.getTopLeft(find.text('INVOICES')).dx,
    );
    expect(
      tester.getTopRight(find.text('CHF 200.00')).dx,
      closeTo(tester.getTopRight(find.text('OWES')).dx, 0.5),
    );
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
    final parts = find.byType(DecoratedBox);
    expect(parts, findsNWidgets(2));
    // Drawn, not collapsed: each part is as tall as the bar and as wide as
    // its share.
    final first = tester.getSize(parts.first);
    final last = tester.getSize(parts.last);
    expect(first.height, greaterThan(0));
    expect(first.width, greaterThan(last.width * 2));
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
