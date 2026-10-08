// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Money action labels wrap at the chosen text size without clipping.
import 'package:deskilo/features/money/presentation/widgets/money_faces_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long label wraps at doubled text without shrinking',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: Scaffold(
        // Narrower than the word: the worst case a phone can produce.
        body: Center(
          child: SizedBox(width: 96, child: fittedLabel('Documents')),
        ),
      ),
    ));
    final text = tester.widget<Text>(find.text('Documents'));
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Documents'));
    expect(paragraph.textScaler.scale(14), 28);
    expect(text.maxLines, isNull);
    expect(find.ancestor(of: find.text('Documents'), matching: find.byType(FittedBox)),
        findsNothing);
    final box = tester.getSize(find.text('Documents'));
    expect(box.height, greaterThan(40));
  });
}
