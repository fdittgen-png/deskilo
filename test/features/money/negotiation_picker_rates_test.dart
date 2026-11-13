// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3819 — the occupation picker of a price negotiation prints each level as a
// rate through the formatting boundary: the locale's own percent form, never
// a literal space and sign built into a message.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/money/presentation/widgets/negotiation_card.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<void> _openPicker(WidgetTester tester, String formatLocale) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: FakeMoneyRepository(), pinFormats: false),
        ...formatPinOverrides(locale: formatLocale),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showPriceNegotiationSheet(
              context,
              ref,
              memberId: 'member-2',
              memberName: 'Ana',
              currency: moneyFormat('EUR', locale: formatLocale),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('negotiation-occupation')));
  await tester.pumpAndSettle();
}

String _plain(String s) => s.replaceAll(RegExp('[\u00a0\u202f]'), ' ');

void main() {
  const forms = {'en_GB': '75%', 'de_DE': '75 %', 'fr_FR': '75 %'};
  for (final MapEntry(key: locale, value: form) in forms.entries) {
    testWidgets('the picker reads 75 in the form of $locale', (tester) async {
      await _openPicker(tester, locale);
      final shown = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          _plain(t.data ?? ''),
      ];
      expect(shown, contains(form));
    });
  }
}
