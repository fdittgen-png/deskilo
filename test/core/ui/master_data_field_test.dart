// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3563 -- a field that names master data is a lookup: the options list the
// catalogue (name · code, in the reader's language), typing searches name and
// code ignoring case and accents, a typed or pasted valid code is accepted, a
// code outside the catalogue shows its error and is never cleared, and a pick
// stores the ISO code.
import 'package:deskilo/core/ui/country_field.dart';
import 'package:deskilo/core/ui/currency_field.dart';
import 'package:deskilo/core/ui/master_data_field.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

const _key = ValueKey('country-test');

void main() {
  test('search folds case and accents and matches name or code', () {
    const options = [
      MasterDataOption(code: 'CI', name: "Côte d'Ivoire"),
      MasterDataOption(code: 'CH', name: 'Switzerland'),
      MasterDataOption(code: 'DE', name: 'Germany'),
    ];
    expect(optionsMatching(options, 'COTE').single.code, 'CI');
    expect(optionsMatching(options, 'swi').single.code, 'CH');
    expect(optionsMatching(options, 'de').map((o) => o.code), contains('DE'));
    expect(optionsMatching(options, '').length, 3);
    expect(optionNamed(options, 'ch')?.code, 'CH');
    expect(optionNamed(options, 'Germany · DE')?.code, 'DE');
    expect(optionNamed(options, 'ZZ'), isNull);
  });

  testWidgets('opening lists the catalogue; picking stores the ISO code', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _host(CountryField(textKey: _key, controller: controller, label: 'Country')),
    );
    await tester.tap(find.byKey(_key));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets, reason: 'the catalogue is listed');
    await tester.enterText(find.byKey(_key), 'swi');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('master-data-option-CH')));
    await tester.pumpAndSettle();
    expect(controller.text, 'CH');
    expect(find.text('Switzerland · CH'), findsOneWidget);
  });

  for (final (locale, typed, shown) in [
    (const Locale('en'), 'swi', 'Switzerland · CH'),
    (const Locale('de'), 'sch', 'Schweiz · CH'),
  ]) {
    testWidgets('typing "$typed" finds Switzerland in ${locale.languageCode}', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(
          CountryField(textKey: _key, controller: controller, label: 'Country'),
          locale: locale,
        ),
      );
      await tester.enterText(find.byKey(_key), typed);
      await tester.pumpAndSettle();
      expect(find.text(shown), findsOneWidget);
    });
  }

  testWidgets('a pasted valid code is accepted; an invalid one shows the error', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _host(CountryField(textKey: _key, controller: controller, label: 'Country')),
    );
    await tester.enterText(find.byKey(_key), 'fr');
    await tester.pumpAndSettle();
    expect(controller.text, 'FR');
    expect(isKnownOrEmptyCountry(controller.text), isTrue);
    expect(find.text('This is not a valid entry. Pick one from the list.'), findsNothing);
    await tester.enterText(find.byKey(_key), 'ZZ');
    await tester.pumpAndSettle();
    expect(controller.text, 'ZZ');
    expect(isKnownOrEmptyCountry(controller.text), isFalse);
    expect(find.text('This is not a valid entry. Pick one from the list.'), findsOneWidget);
  });

  testWidgets('a stored code outside the catalogue is shown with its error', (tester) async {
    final controller = TextEditingController(text: 'XX');
    await tester.pumpWidget(
      _host(CountryField(textKey: _key, controller: controller, label: 'Country')),
    );
    expect(find.text('XX'), findsOneWidget);
    expect(find.text('This is not a valid entry. Pick one from the list.'), findsOneWidget);
    expect(controller.text, 'XX');
  });

  testWidgets('the currency field lists the supported currencies', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _host(CurrencyField(textKey: _key, controller: controller, label: 'Currency')),
    );
    await tester.enterText(find.byKey(_key), 'chf');
    await tester.pumpAndSettle();
    expect(controller.text, 'CHF');
    expect(find.byKey(const ValueKey('master-data-option-CHF')), findsOneWidget);
  });

  testWidgets('no overflow at 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'CH');
    await tester.pumpWidget(
      _host(CountryField(textKey: _key, controller: controller, label: 'Country of the supplier')),
    );
    await tester.tap(find.byKey(_key));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
