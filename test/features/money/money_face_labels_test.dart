// SPDX-License-Identifier: 0BSD
//
// #902 — a Finances tab label NEVER wraps: "Documents" was breaking into
// "Document" + "s". It shrinks to the width its tab is given and, at the
// very worst, ends in an ellipsis.
import 'package:deskilo/features/money/presentation/widgets/money_faces_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long label shrinks to one line instead of wrapping',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // Narrower than the word: the worst case a phone can produce.
        body: Center(
          child: SizedBox(width: 48, child: fittedLabel('Documents')),
        ),
      ),
    ));
    final text = tester.widget<Text>(find.text('Documents'));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(find.ancestor(of: find.text('Documents'), matching: find.byType(FittedBox)),
        findsOneWidget);
    // One line: the rendered box is no taller than a single line of text.
    final box = tester.getSize(find.text('Documents'));
    final line = tester.renderObject<RenderBox>(find.text('Documents'));
    expect(box.height, lessThanOrEqualTo(line.size.height + 0.5));
  });
}
