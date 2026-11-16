// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4098 -- the phone's bottom bar draws its labels whole or not at all, one
// decision for all tabs: every label on one line, else every label within two
// lines broken only at a space, else icons alone with tooltip and spoken name.
// On a phone at 360 and 390 px with text 1.0 the labels ARE drawn, in each of
// the five languages; at 320 px or text 1.3 they are whole or none. Never a
// label cut, never one below the theme's size.
import 'package:deskilo/app/shell/shell_bar_labels.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ux/experience_guards.dart' show loadRealFonts;

/// The case the bar is in: [ShellBarLabels.none] when no tab draws a label.
ShellBarLabels _caseOf(WidgetTester tester) {
  final boxes = [
    for (final e
        in find
            .descendant(
              of: find.descendant(
                of: find.byType(ShellBarTab),
                matching: find.byType(Text),
              ),
              matching: find.byType(RichText),
            )
            .evaluate())
      e.renderObject! as RenderParagraph,
  ];
  if (boxes.isEmpty) return ShellBarLabels.none;
  return boxes.any((b) => _lines(b) > 1)
      ? ShellBarLabels.twoLines
      : ShellBarLabels.oneLine;
}

/// The lines [box] was laid out in.
int _lines(RenderParagraph box) => {
  for (final b in box.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: box.text.toPlainText().length),
  ))
    b.top.round(),
}.length;

/// Whether every word of [box] is on a line of its own width: no word is
/// broken, since a break inside one needs a word wider than the paragraph.
bool _wordsWhole(RenderParagraph box) {
  for (final word in box.text.toPlainText().split(' ')) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: (box.text as TextSpan).style),
      textDirection: TextDirection.ltr,
      textScaler: box.textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width > box.size.width + 0.01) return false;
  }
  return true;
}

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
    for (final width in const [320.0, 360.0, 390.0]) {
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
          final bar = _caseOf(tester);
          // A phone at text 1.0 shows its labels.
          if (width >= 360 && scale == 1.0) {
            expect(bar, isNot(ShellBarLabels.none), reason: '$labels');
          }
          final texts = find.descendant(
            of: find.descendant(
              of: find.byType(ShellBarTab),
              matching: find.byType(Text),
            ),
            matching: find.byType(RichText),
          );
          // One decision for every tab: all the labels, or none.
          expect(
            texts.evaluate().length,
            bar == ShellBarLabels.none ? 0 : labels.length,
          );
          for (final e in texts.evaluate()) {
            final box = e.renderObject! as RenderParagraph;
            expect(
              box.didExceedMaxLines,
              isFalse,
              reason: '"${box.text.toPlainText()}" in ${box.size.width}',
            );
            expect(
              _wordsWhole(box),
              isTrue,
              reason: '"${box.text.toPlainText()}" has a word broken',
            );
            expect(_lines(box), lessThanOrEqualTo(2));
            // The theme's size, whatever the case.
            expect(
              (box.text as TextSpan).style?.fontSize,
              Theme.of(tester.element(find.byType(ShellBottomBar)))
                  .textTheme
                  .labelMedium
                  ?.fontSize,
            );
          }
          // Drawn or not, each tab has its whole name for a screen reader,
          // and without the label on screen it is the tooltip as well.
          for (final label in labels) {
            expect(find.bySemanticsLabel(label), findsWidgets);
            if (bar == ShellBarLabels.none) {
              expect(find.byTooltip(label), findsOneWidget);
            }
          }
          semantics.dispose();
        });
      }
    }
  }

  testWidgets('a wide window keeps every label on one line', (tester) async {
    for (final language in _languages) {
      final labels = await _pump(
        tester,
        language: language,
        width: 800,
        scale: 1,
      );
      expect(_caseOf(tester), ShellBarLabels.oneLine, reason: language);
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: language);
      }
    }
  });
}
