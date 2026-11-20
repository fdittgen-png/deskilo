// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4223 — the words of places, held in one place: a business that keeps its
// places off must read none of them on the pages of its guide. Whole words
// (the product's own name contains "desk").
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final placeVocabulary = RegExp(
  r'\b(seats?|desks?|(?<!reminder )levels?|floor ?plans?|kiosks?|badges?|'
  r'check[- ]?ins?|meeting rooms?|half-?days?|day packs?)\b',
  caseSensitive: false,
);

/// The place words on screen, each with the text that holds it.
List<String> placeWordsShown(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.byType(Text, skipOffstage: false),
  ))
    if (placeVocabulary.hasMatch(t.data ?? t.textSpan?.toPlainText() ?? ''))
      t.data ?? t.textSpan!.toPlainText(),
];
