// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3767 -- the start button of a booking period is ONE message that takes the
// workspace's own word for "From": a business that renamed the term sees its
// word, a business that did not sees the product's.
import 'package:deskilo/core/l10n/lexicon.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _button(WidgetTester tester) async {
  late String text;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          text = l10n.planFromTermTime(
            lexiconText(context, key: 'planFromLabel', fallback: l10n.planFromLabel),
            '09:00',
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return text;
}

void main() {
  tearDown(Lexicon.reset);

  testWidgets('without a renamed term the product word leads the time', (
    tester,
  ) async {
    expect(await _button(tester), 'From 09:00');
  });

  testWidgets('a renamed term is the word on the button', (tester) async {
    Lexicon.install({
      'en': {'planFromLabel': 'Arriving'},
    });
    expect(await _button(tester), 'Arriving 09:00');
  });
}
