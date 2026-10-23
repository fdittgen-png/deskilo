// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the VAT step of the setup guide. The rates in force are listed
// as stored, the default starred. A workspace without rates is offered its
// country's usual ones only where the tax reference data has them (the
// fixture is German: 19 / 7), and offering stores them through the VAT
// screen's write; a country the data does not know is told so, nothing is
// invented. The preview splits a sample line with the app's own `vatSplit`
// at the default rate, and charges nothing outside VAT registration. One
// column on a phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/money/domain/report_data_sample.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

FakeWorkspaceRepository _repo({
  String regime = 'not_subject',
  String country = 'DE',
}) {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    vatRegime: regime,
    countryCode: country,
  );
  return repo;
}

FakeMoneyRepository _registeredRates() => FakeMoneyRepository()
  ..vatRates = const [
    VatRate(id: 'v-19', label: 'Standard', percent: 19, isDefault: true),
    VatRate(id: 'v-7', label: 'Reduced', percent: 7),
  ];

Future<void> _pump(
  WidgetTester tester, {
  required FakeWorkspaceRepository repo,
  FakeMoneyRepository? money,
}) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'vat', growPages: setupGrowPages),
    size: _phone,
    overrides: standardTestOverrides(workspace: repo, money: money),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('no rate yet: the country\'s usual rates from the reference '
      'data are offered, and offering stores them, standard first', (
    tester,
  ) async {
    final money = FakeMoneyRepository();
    await _pump(tester, repo: _repo(), money: money);
    expect(find.byKey(const ValueKey('setup-vat-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-vat-regime-hint')), findsOneWidget);
    final usual = find.byKey(const ValueKey('setup-vat-usual'));
    expect(
      find.descendant(of: usual, matching: find.text('19 %')),
      findsOneWidget,
    );
    expect(money.vatRates, isEmpty, reason: 'nothing is stored before');
    // Outside VAT registration the sample line carries no VAT.
    expect(
      find.byKey(const ValueKey('setup-vat-preview-none')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('setup-vat-use-usual')));
    await tester.pumpAndSettle();
    expect(money.vatRates.map((r) => r.percent), [19, 7]);
    expect(money.vatRates.first.isDefault, isTrue);
    expect(find.byKey(const ValueKey('setup-vat-usual')), findsNothing);
    expect(find.byKey(const ValueKey('setup-vat-rate-0')), findsOneWidget);
  });

  testWidgets('a country the reference data does not know is told so, and '
      'no rate is invented', (tester) async {
    await _pump(tester, repo: _repo(country: 'ZZ'));
    expect(
      find.byKey(const ValueKey('setup-vat-no-catalogue')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-vat-usual')), findsNothing);
  });

  testWidgets('VAT-registered: the stored rates, the default starred, and a '
      'sample line split by vatSplit at the default rate', (tester) async {
    await _pump(
      tester,
      repo: _repo(regime: 'vat_registered'),
      money: _registeredRates(),
    );
    final standard = tester.widget<ListTile>(
      find.byKey(const ValueKey('setup-vat-rate-0')),
    );
    expect((standard.leading! as Icon).icon, Icons.star);
    expect((standard.trailing! as Text).data, '19 %');
    expect(find.byKey(const ValueKey('setup-vat-usual')), findsNothing);

    final split = vatSplit(SampleInvoice.grossCents, 19);
    final euro = moneyFormat(
      'EUR',
      locale: Localizations.localeOf(
        tester.element(find.byKey(const ValueKey('setup-vat-preview-split'))),
      ).toString(),
    );
    expect(
      _text(tester, 'setup-vat-preview-net'),
      euro.formatMinor(split.netCents),
    );
    expect(
      _text(tester, 'setup-vat-preview-vat'),
      euro.formatMinor(split.vatCents),
    );
    expect(
      _text(tester, 'setup-vat-preview-gross'),
      euro.formatMinor(SampleInvoice.grossCents),
    );
    // The same split, written out: 120.00 incl. 19 % is 100.84 + 19.16.
    expect(_text(tester, 'setup-vat-preview-net'), contains('100.84'));
    expect(_text(tester, 'setup-vat-preview-vat'), contains('19.16'));
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(
      tester,
      repo: _repo(regime: 'vat_registered'),
      money: _registeredRates(),
    );
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
