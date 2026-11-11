// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3682 — Me › Finances says nothing is owed only when every source
// answered: a connected host still being read or that failed leaves each
// empty list saying only what was read so far; a list of connected hosts
// that cannot be read is a source that did not answer, with Try again,
// never "none"; and an invoice whose payment is being validated is paid on
// my side — never to pay, never late, said on its own line per currency.
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/presentation/screens/my_finances_screen.dart';
import 'package:deskilo/features/money/providers/finance_host_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice, show;

const _lyon = FinanceHost(
  installationId: 'inst-b',
  workspaceIds: ['ws-Lyon'],
  labels: ['Lyon'],
);

final _now = DateTime(2026, 11, 10, 12);

Finder _key(String key) => find.byKey(ValueKey(key));

const _upToDate = 'Nothing to pay — you are up to date.';
const _soFar = 'Nothing among what was read so far.';

FinanceInvoice _validating(String id, {String currency = 'EUR'}) => invoice(
  id,
  state: FinanceState.awaitingValidation,
  total: 12000,
  currency: currency,
  due: DateTime(2020),
);

/// Each tab's empty state says [text].
Future<void> _everyEmptyStateSays(WidgetTester tester, String text) async {
  for (final (tab, empty) in [
    ('finances-tab-outstanding', 'finances-outstanding-empty'),
    ('finances-tab-paid', 'finances-paid-empty'),
    ('finances-tab-reminders', 'finances-reminders-empty'),
  ]) {
    await tester.tap(_key(tab));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _key(empty), matching: find.text(text)),
      findsOneWidget,
      reason: empty,
    );
  }
}

void main() {
  group('a source that has not answered', () {
    for (final status in [
      FinanceHostStatus.reading,
      FinanceHostStatus.failed,
    ]) {
      testWidgets('a connected host ${status.name}: no list says it is '
          'complete', (tester) async {
        await show(
          tester,
          const FinanceOverview(
            hosts: [FinanceHostRead(_lyon, FinanceHostStatus.reading)],
          ).hostSettled(_lyon, status),
        );
        expect(find.text(_upToDate), findsNothing);
        await _everyEmptyStateSays(tester, _soFar);
      });
    }

    testWidgets('every source answered: the empty lists are complete', (
      tester,
    ) async {
      await show(tester, const FinanceOverview());
      expect(find.text(_upToDate), findsOneWidget);
      expect(find.text(_soFar), findsNothing);
    });

    testWidgets('the list of my connected hosts cannot be read: a source '
        'that did not answer, with Try again; never "none"', (tester) async {
      var hostsDown = true;
      await pumpApp(
        tester,
        const MyFinancesScreen(),
        size: const Size(800, 1400),
        overrides: [
          ...standardTestOverrides(auth: FakeAuthRepository.signedIn()),
          financeHostsProvider.overrideWith(
            (ref) async => hostsDown
                ? throw const FinanceHostUnavailable('down')
                : const <FinanceHost>[],
          ),
        ],
      );
      await tester.pumpAndSettle();
      final banner = _key('finances-source-unavailable-$connectedHostsSource');
      expect(banner, findsOneWidget);
      expect(
        find.descendant(
          of: banner,
          matching: find.textContaining('connected installations'),
        ),
        findsOneWidget,
      );
      expect(find.text(_upToDate), findsNothing);
      expect(find.text(_soFar), findsOneWidget);
      expect(
        _key('finances-retry'),
        findsNothing,
        reason: 'the home answered: not the whole overview failing',
      );

      hostsDown = false;
      await tester.tap(
        find.descendant(of: banner, matching: find.text('Try again')),
      );
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(find.text(_upToDate), findsOneWidget);
    });
  });

  group('a payment being validated', () {
    test('is an open document, never to pay, never late, never owed', () {
      final paid = _validating('v');
      expect(paid.overdueAt(_now), isFalse);
      final o = FinanceOverview(
        invoices: [
          paid,
          _validating('w', currency: 'CHF'),
          invoice('a', total: 3000, due: DateTime(2020)),
        ],
      );
      expect(o.outstanding.map((i) => i.id), containsAll(['v', 'w', 'a']));
      expect(o.payable.map((i) => i.id), ['a']);
      expect(o.owedByCurrency, {'EUR': 3000});
      expect(o.beingValidatedByCurrency, {'CHF': 12000, 'EUR': 12000});
      expect(o.overdueCurrencies(_now), {'EUR'});
    });

    test('a credit of its business is not taken off it', () {
      final o = FinanceOverview(
        invoices: [_validating('v'), invoice('c', total: -2000)],
      );
      expect(o.owedByCurrency, isEmpty);
      expect(o.inMyFavourByCurrency, {'EUR': 2000});
      expect(o.beingValidatedByCurrency, {'EUR': 12000});
    });

    testWidgets('is said on its own line, outside To pay, with its status '
        'and never late', (tester) async {
      await show(
        tester,
        FinanceOverview(
          invoices: [_validating('v'), invoice('a', total: 3000)],
        ),
      );
      expect(
        tester.widget<Text>(_key('finances-to-pay-EUR')).data,
        contains('30'),
      );
      expect(
        tester.widget<Text>(_key('finances-being-validated-EUR')).data,
        contains('120'),
      );
      expect(find.text('Being validated'), findsOneWidget);
      expect(_key('finances-overdue'), findsNothing);
      expect(
        find.descendant(
          of: _key('finances-invoice-v'),
          matching: find.text('Payment being validated'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('finances-invoice-v'),
          matching: find.textContaining('Overdue'),
        ),
        findsNothing,
      );
    });

    testWidgets('alone: nothing to pay is claimed', (tester) async {
      await show(tester, FinanceOverview(invoices: [_validating('v')]));
      expect(_key('finances-to-pay-EUR'), findsNothing);
      expect(_key('finances-being-validated-EUR'), findsOneWidget);
      expect(_key('finances-invoice-v'), findsOneWidget);
    });
  });
}
