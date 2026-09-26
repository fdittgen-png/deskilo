// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1656 group 1 — a template's region is offered at creation, never
// applied on its own, and malformed values are not offered at all.
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_region_notice.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _de = RegionalSuggestion(
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
);

Future<void> _pump(
  WidgetTester tester,
  RegionalSuggestion s, {
  String country = 'FR',
  String currency = 'EUR',
  String tz = 'Europe/Paris',
  VoidCallback? onUse,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TemplateRegionNotice(
        suggestion: s,
        countryCode: country,
        currencyCode: currency,
        timezone: tz,
        onUse: onUse ?? () {},
      ),
    ),
  ),
);

void main() {
  test('only well-formed values are read', () {
    final s = RegionalSuggestion.fromJson({
      'country_code': 'de',
      'currency_code': 'EURO',
      'timezone': 'Europe/Berlin',
      'locale': 'de',
      'origin': 'source_workspace',
    });
    expect(s.countryCode, isNull);
    expect(s.currencyCode, isNull);
    expect(s.timezone, 'Europe/Berlin');
    expect(RegionalSuggestion.fromJson(null).isEmpty, isTrue);
    expect(RegionalSuggestion.fromJson(<String, Object?>{}).isEmpty, isTrue);
  });

  test('a suggestion differs only where it says something', () {
    expect(
      _de.differsFrom(
        countryCode: 'DE',
        currencyCode: 'eur',
        timezone: 'Europe/Berlin',
      ),
      isFalse,
    );
    expect(
      _de.differsFrom(
        countryCode: 'FR',
        currencyCode: 'EUR',
        timezone: 'Europe/Paris',
      ),
      isTrue,
    );
    expect(
      const RegionalSuggestion(timezone: 'Europe/Berlin').differsFrom(
        countryCode: 'FR',
        currencyCode: 'CHF',
        timezone: 'Europe/Berlin',
      ),
      isFalse,
    );
  });

  testWidgets('a different region is offered and used only on request', (
    tester,
  ) async {
    var used = 0;
    await _pump(tester, _de, onUse: () => used++);
    expect(
      find.byKey(const ValueKey('template-region-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('DE · EUR · Europe/Berlin'), findsOneWidget);
    expect(used, 0);
    await tester.tap(find.byKey(const ValueKey('template-region-use')));
    expect(used, 1);
  });

  testWidgets(
    'the same region, no suggestion or an unknown country: nothing shown',
    (tester) async {
      await _pump(tester, _de, country: 'DE', tz: 'Europe/Berlin');
      expect(
        find.byKey(const ValueKey('template-region-notice')),
        findsNothing,
      );
      await _pump(tester, const RegionalSuggestion());
      expect(
        find.byKey(const ValueKey('template-region-notice')),
        findsNothing,
      );
      await _pump(tester, const RegionalSuggestion(countryCode: 'ZZ'));
      expect(
        find.byKey(const ValueKey('template-region-notice')),
        findsNothing,
      );
    },
  );
}
