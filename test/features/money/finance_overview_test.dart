// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3877 — what Me says is to pay and being validated comes from the server's
// own figures per invoice (`still_due_cents`, `awaiting_cents`, 0755), never
// from the aggregate's paid amount and its state: a further part of a payment
// that waits for approval is paid on my side, the rest of a pending partial is
// still to pay. #3878 — the answer says when older settled documents were left
// out.
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/my_finances_screen.dart' show show;

/// One of MY invoices of EUR 100 as `my_finance_overview` answers it.
Map<String, dynamic> _row({
  required String state,
  required int paid,
  int? stillDue,
  int? awaiting,
}) => {
  'id': 'inv-1',
  'workspace_id': 'ws-1',
  'workspace_name': 'Space',
  'number': 'F-1',
  'issued_at': '2026-11-01T09:00:00Z',
  'total_cents': 10000,
  'currency': 'EUR',
  'paid_cents': paid,
  'state': state,
  'still_due_cents': ?stillDue,
  'awaiting_cents': ?awaiting,
};

FinanceOverview _overview(Map<String, dynamic> row, {bool? cut}) =>
    FinanceOverview.fromJson({
      'invoices': [row],
      'reminders': const <Object?>[],
      'settled_cut': ?cut,
    });

void main() {
  test('(a) a first partial of 40 awaiting approval: 40 being validated, '
      'the 60 nobody paid still to pay', () {
    final o = _overview(
      _row(
        state: 'awaiting_validation',
        paid: 4000,
        stillDue: 6000,
        awaiting: 4000,
      ),
    );
    expect(o.beingValidatedByCurrency, {'EUR': 4000});
    expect(o.owedByCurrency, {'EUR': 6000});
    expect([for (final i in o.payable) i.remainingCents], [6000]);
  });

  test('(b) a confirmed partial of 40 and a further 60 awaiting approval: '
      'nothing to pay, 60 being validated', () {
    final o = _overview(
      _row(state: 'partially_paid', paid: 4000, stillDue: 0, awaiting: 6000),
    );
    expect(o.beingValidatedByCurrency, {'EUR': 6000});
    expect(o.owedByCurrency, isEmpty);
    expect(o.payable, isEmpty);
  });

  test('a host that answers no figures is read as before', () {
    final o = _overview(_row(state: 'awaiting_validation', paid: 4000));
    expect(o.beingValidatedByCurrency, {'EUR': 10000});
    expect(o.owedByCurrency, isEmpty);
    final partial = _overview(_row(state: 'partially_paid', paid: 4000));
    expect(partial.owedByCurrency, {'EUR': 6000});
  });

  test('#3878 — an answer whose older settled documents were left out says '
      'so, and the flag survives a merge', () {
    final cut = _overview(_row(state: 'paid', paid: 10000), cut: true);
    expect(cut.olderSettledLeftOut, isTrue);
    expect(const FinanceOverview().merge(cut).olderSettledLeftOut, isTrue);
    expect(
      _overview(_row(state: 'paid', paid: 10000)).olderSettledLeftOut,
      isFalse,
    );
  });

  testWidgets('#3878 — the coverage says when older paid documents are not '
      'listed, and only then', (tester) async {
    await show(tester, _overview(_row(state: 'paid', paid: 10000), cut: true));
    expect(
      find.byKey(const ValueKey('finances-coverage-older-settled')),
      findsOneWidget,
    );
    await show(tester, _overview(_row(state: 'paid', paid: 10000)));
    expect(
      find.byKey(const ValueKey('finances-coverage-older-settled')),
      findsNothing,
    );
  });
}
