// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4414 -- the shared failed read: worded by its kind, or by a typed
// refusal's own words, and Try again repeats the read either way.
import 'package:deskilo/core/ui/async_read_body.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

Future<void> _pump(WidgetTester tester, Widget banner) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: banner),
  ),
);

void main() {
  testWidgets(
    'a plain failure is worded by its kind, and Try again asks again',
    (tester) async {
      var retried = 0;
      await _pump(
        tester,
        ReadFailureBanner(error: StateError('x'), onRetry: () => retried++),
      );
      expect(find.text(_en.readStateFailed), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inline-banner-action')));
      expect(retried, 1);
    },
  );

  testWidgets('a typed refusal is said in its own words, with the same retry', (
    tester,
  ) async {
    var retried = 0;
    await _pump(
      tester,
      ReadFailureBanner(
        error: StateError('x'),
        refusal: 'This quote is not yours to see.',
        retryKey: const ValueKey('quote-retry'),
        onRetry: () => retried++,
      ),
    );
    expect(find.text('This quote is not yours to see.'), findsOneWidget);
    expect(find.text(_en.readStateFailed), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-retry')));
    expect(retried, 1);
  });
}
