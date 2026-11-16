// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4094 -- a record's bar names it by its number: on a phone the number is
// never the part that is cut. The words and the number when both fit; the
// number alone when they do not, with the whole name for a screen reader.
import 'package:deskilo/core/ui/kit/page_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'experience_guards.dart';

Future<void> _open(
  WidgetTester tester, {
  required String text,
  required String number,
  required double scale,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: PageTitle(text, whenCut: number),
          actions: [
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            IconButton(icon: const Icon(Icons.close), onPressed: () {}),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);
  // The longest number format the Demo holds, with the words of each
  // language's invoice title.
  const number = 'INV-2026-0001';
  const titles = [
    'Invoice $number',
    'Rechnung $number',
    'Facture $number',
    'Factura $number',
    'Fattura $number',
  ];
  for (final scale in [1.0, 1.3]) {
    for (final text in titles) {
      testWidgets('the bar at 390 px, text $scale: "$text" keeps its number '
          'whole', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, text: text, number: number, scale: scale);
        final whole = find.text(text);
        final alone = find.text(number);
        // Exactly one of the two is drawn, and none is cut.
        expect(whole.evaluate().length + alone.evaluate().length, 1);
        final drawn = whole.evaluate().isNotEmpty ? whole : alone;
        final details = <String>[];
        expect(
          cutInformationProblems(details: details),
          isEmpty,
          reason: details.join('\n'),
        );
        // The bar's text keeps the theme's size.
        expect(tester.widget<Text>(drawn).style?.fontSize, isNull);
        // Whatever is drawn, a screen reader gets the whole name.
        expect(find.bySemanticsLabel(text), findsOneWidget);
        semantics.dispose();
      });
    }
  }

  testWidgets('a title that fits stays whole, words and number', (
    tester,
  ) async {
    await _open(tester, text: 'Invoice 7', number: '7', scale: 1);
    expect(find.text('Invoice 7'), findsOneWidget);
  });
}
