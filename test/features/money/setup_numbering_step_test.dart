// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the numbering step of the setup guide. The invoice series' card
// arrives prefilled from the stored series and saves through the number
// sequences screen's own write; the preview is the number the next invoice
// will carry, formatted by the series' own formatter from the stored next
// value. Showing it, editing and saving take no number: the next value is
// unchanged after all of it. One column on a phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

const _stored = NumberSequence(
  journal: 'invoice',
  prefix: 'FA-',
  nextValue: 42,
  stored: true,
);

FakeMoneyRepository _money() =>
    FakeMoneyRepository()..numberSequences['invoice'] = _stored;

Future<void> _pump(WidgetTester tester, FakeMoneyRepository money) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'numbering', growPages: setupGrowPages),
    size: _phone,
    overrides: standardTestOverrides(money: money),
  );
  await tester.pumpAndSettle();
}

String _next(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('setup-numbering-next')))
    .data!;

void main() {
  testWidgets('the next number is the series\' own format of the stored next '
      'value, and showing it takes none', (tester) async {
    final money = _money();
    await _pump(tester, money);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('number-sequence-prefix-invoice')),
          )
          .controller!
          .text,
      'FA-',
    );
    expect(_next(tester), _stored.format(42, kTestNow));
    expect(_next(tester), 'FA-${kTestNow.year}-0042');
    expect(money.numberSequences['invoice']!.nextValue, 42);
    expect(money.lastNumberSequence, isNull, reason: 'nothing written');
  });

  testWidgets('Save stores the new format and the preview follows, still at '
      'the same next value', (tester) async {
    final money = _money();
    await _pump(tester, money);
    await tester.enterText(
      find.byKey(const ValueKey('number-sequence-prefix-invoice')),
      'INV-',
    );
    await tester.pump();
    expect(_next(tester), 'FA-${kTestNow.year}-0042', reason: 'not saved yet');

    await tester.tap(
      find.byKey(const ValueKey('number-sequence-save-invoice')),
    );
    await tester.pumpAndSettle();
    expect(money.numberSequences['invoice']!.prefix, 'INV-');
    expect(money.numberSequences['invoice']!.nextValue, 42);
    expect(_next(tester), 'INV-${kTestNow.year}-0042');
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(tester, _money());
    expect(find.byKey(const ValueKey('setup-numbering-lock')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
