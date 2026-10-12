// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2440 — a seller on the small-business exemption is told when its net
// turnover of the year nears or passes the limit that ends it: the rows
// (DE § 19 UStG: 25 000 next year, 100 000 at once; FR CGI art. 293 B,
// unconfirmed for 2026), the turnover the year counts, and the notice.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/small_business_threshold.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/presentation/widgets/small_business_notice.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Invoice _invoice(
  int netCents, {
  int? year,
  bool voided = false,
  String id = 'inv',
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: id,
  issuedAt: DateTime(year ?? kTestNow.year, 3, 4),
  period: '2026-03',
  title: id,
  lines: const [],
  totalCents: netCents,
  currency: 'EUR',
  memberName: 'Kunde',
  memberAddress: '',
  workspaceName: 'Demo',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  voidedAt: voided ? DateTime(2026, 4) : null,
  vatTotals: [
    InvoiceVatTotal(
      percent: 0,
      category: 'E',
      grossCents: netCents,
      netCents: netCents,
      vatCents: 0,
    ),
  ],
);

List<SmallBusinessAlert> _alerts(String country, int cents) =>
    smallBusinessAlerts(
      country: country,
      currency: 'EUR',
      turnoverCents: cents,
    );

void main() {
  test('the year counts issued, unvoided net turnover of that year only', () {
    expect(
      turnoverOfYear([
        _invoice(1000, id: 'a'),
        _invoice(2000, id: 'b', voided: true),
        _invoice(4000, id: 'c', year: kTestNow.year - 1),
      ], kTestNow.year),
      1000,
    );
  });

  test('Germany: near and passed 25 000 (next year), near and passed '
      '100 000 (at once)', () {
    expect(_alerts('DE', 1000000), isEmpty);
    final near = _alerts('DE', 2000000).single;
    expect(near.level, ThresholdLevel.near);
    expect(near.threshold.effect, ThresholdEffect.nextYear);
    final passed = _alerts('DE', 2500000).first;
    expect(passed.level, ThresholdLevel.passed);
    // Past 80 000 the higher row speaks first.
    final both = _alerts('DE', 8500000);
    expect(both.first.threshold.cents, 10000000);
    expect(both.first.level, ThresholdLevel.near);
    expect(both.first.threshold.effect, ThresholdEffect.immediate);
    expect(_alerts('DE', 10000000).first.level, ThresholdLevel.passed);
  });

  test('the rows: only euro, only known countries; the French ones say '
      'they are unconfirmed', () {
    expect(
      smallBusinessAlerts(
        country: 'DE',
        currency: 'CHF',
        turnoverCents: 99999999,
      ),
      isEmpty,
    );
    expect(_alerts('IT', 99999999), isEmpty);
    expect(_alerts('de', 2500000), isNotEmpty);
    expect(
      _alerts('FR', 99999999).every((a) => !a.threshold.confirmed),
      isTrue,
    );
    expect(_alerts('DE', 99999999).every((a) => a.threshold.confirmed), isTrue);
  });

  Future<void> pump(
    WidgetTester tester, {
    required String regime,
    required String country,
    required int netCents,
  }) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      vatRegime: regime,
      countryCode: country,
      currencyCode: 'EUR',
    );
    final money = FakeMoneyRepository()..invoices.add(_invoice(netCents));
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: workspace),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SmallBusinessNotice(
              exempt: regime == 'exempt',
              country: country,
              currency: 'EUR',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const key = ValueKey('small-business-notice');

  testWidgets('a German exempt seller past 25 000 is told the exemption '
      'ends with the year', (tester) async {
    await pump(tester, regime: 'exempt', country: 'DE', netCents: 2600000);
    expect(find.byKey(key), findsOneWidget);
    expect(find.textContaining('ends with this year'), findsOneWidget);
    expect(find.textContaining('check the current figure'), findsNothing);
  });

  testWidgets('a French seller is told, and asked to check the figure', (
    tester,
  ) async {
    await pump(tester, regime: 'exempt', country: 'FR', netCents: 4200000);
    expect(find.byKey(key), findsOneWidget);
    expect(find.textContaining('check the current figure'), findsOneWidget);
  });

  testWidgets('a VAT-registered seller, or a small turnover: no notice', (
    tester,
  ) async {
    await pump(
      tester,
      regime: 'vat_registered',
      country: 'DE',
      netCents: 9900000,
    );
    expect(find.byKey(key), findsNothing);
    await pump(tester, regime: 'exempt', country: 'DE', netCents: 100000);
    expect(find.byKey(key), findsNothing);
  });
}
