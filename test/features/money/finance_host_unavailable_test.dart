// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4218 — a host that cannot be reached or verified is said in words, naming
// the invoice's business, with a way to try again: in all five languages, at
// a phone's width and a desk's. A command also says that nothing was sent;
// opening something does not.
import 'package:deskilo/features/money/presentation/finance_host_unavailable.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _widths = [390.0, 1440.0];

Future<void> _show(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  required bool opening,
  VoidCallback? retry,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('go'),
            onPressed: () => showFinanceHostUnavailable(
              context,
              'Lyon',
              opening: opening,
              retry: retry ?? () {},
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in _widths) {
      testWidgets(
        '${locale.languageCode} at $width: a command on an unreachable host '
        'names its business, says nothing was sent and offers to try again',
        (tester) async {
          await _show(tester, locale: locale, width: width, opening: false);
          final l10n = lookupAppLocalizations(locale);
          expect(
            find.text(l10n.financesBusinessUnavailable('Lyon')),
            findsOneWidget,
          );
          expect(find.text(l10n.commonRetry), findsOneWidget);
        },
      );

      testWidgets(
        '${locale.languageCode} at $width: opening on an unreachable host '
        'names its business and offers to try again, and the action retries',
        (tester) async {
          var retried = 0;
          await _show(
            tester,
            locale: locale,
            width: width,
            opening: true,
            retry: () => retried++,
          );
          final l10n = lookupAppLocalizations(locale);
          expect(
            find.text(l10n.financesBusinessUnavailableOpen('Lyon')),
            findsOneWidget,
          );
          expect(retried, 0);
          await tester.tap(find.text(l10n.commonRetry));
          await tester.pump();
          expect(retried, 1, reason: 'the action tries again, once');
        },
      );
    }
  }

  test('the sentence for opening does not claim that anything was sent', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.financesBusinessUnavailableOpen('Lyon'),
        isNot(l10n.financesBusinessUnavailable('Lyon')),
        reason: locale.languageCode,
      );
      expect(l10n.financesBusinessUnavailableOpen('Lyon'), contains('Lyon'));
    }
  });
}
