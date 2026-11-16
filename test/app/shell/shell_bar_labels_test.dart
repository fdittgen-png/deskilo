// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4098 -- the phone's bottom bar draws its labels whole or not at all: in
// each of the five languages, at 320 and 390 px, with text at 1.0 and 1.3,
// either every label is painted to its last letter (no ellipsis, no clip) or
// no tab draws one and each tab is its icon with the label as tooltip and
// spoken name. One decision for all tabs, never a label cut and never a label
// below the theme's size.
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ux/experience_guards.dart' show loadRealFonts;

const _languages = ['en', 'de', 'fr', 'es', 'it'];

/// The bar's tabs as the shell names them, in [l10n]'s words.
List<String> _labels(AppLocalizations l10n) => [
  l10n.inboxAlertsTab,
  l10n.tabCalendar,
  l10n.directoryTitle,
  l10n.tabMoney,
];

Future<List<String>> _pump(
  WidgetTester tester, {
  required String language,
  required double width,
  required double scale,
}) async {
  tester.view
    ..physicalSize = Size(width, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late List<String> labels;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: Locale(language),
        theme: ThemeData(fontFamily: 'Roboto'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            labels = _labels(AppLocalizations.of(context)!);
            return Scaffold(
              bottomNavigationBar: ShellBottomBar(
                destinations: [
                  for (final label in labels)
                    ShellDestination(
                      icon: const Icon(Icons.circle_outlined),
                      selectedIcon: const Icon(Icons.circle),
                      label: label,
                    ),
                ],
                selectedIndex: 1,
                onDestinationSelected: (_) {},
                onReservePressed: () {},
                reserveLabel: 'Reserve',
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return labels;
}

void main() {
  setUpAll(loadRealFonts);

  for (final language in _languages) {
    for (final width in const [320.0, 390.0]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('the bar in $language at ${width.toInt()} px and text '
            '$scale: no label is cut', (tester) async {
          final semantics = tester.ensureSemantics();
          final labels = await _pump(
            tester,
            language: language,
            width: width,
            scale: scale,
          );
          final inBar = find.descendant(
            of: find.byType(ShellBarTab),
            matching: find.byType(Text),
          );
          final drawn = inBar.evaluate().length;
          // One decision for every tab: all the labels, or none.
          expect(drawn, anyOf(0, labels.length), reason: '$labels');
          for (final e
              in find
                  .descendant(
                    of: find.byType(ShellBarTab),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
            final box = e.renderObject! as RenderParagraph;
            expect(
              box.didExceedMaxLines,
              isFalse,
              reason: '"${box.text.toPlainText()}" in ${box.size.width}',
            );
          }
          // Drawn or not, each tab has its whole name for a screen reader,
          // and without the label on screen it is the tooltip as well.
          for (final label in labels) {
            expect(find.bySemanticsLabel(label), findsWidgets);
            if (drawn == 0) expect(find.byTooltip(label), findsOneWidget);
          }
          semantics.dispose();
        });
      }
    }
  }

  testWidgets('a wide window keeps every label drawn', (tester) async {
    for (final language in _languages) {
      final labels = await _pump(
        tester,
        language: language,
        width: 800,
        scale: 1,
      );
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: language);
      }
    }
  });
}
