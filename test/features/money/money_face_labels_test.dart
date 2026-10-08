// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2284 — Money actions remain readable at the user's text size: a long
// label wraps inside its button and the whole action stays tappable.
import 'package:deskilo/features/money/presentation/widgets/money_faces_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long action label wraps without shrinking at doubled text', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(body: Center(child: SizedBox(
          width: 160,
          child: OutlinedButton(
            onPressed: () => tapped = true,
            child: fittedLabel('Monthly consumption report'),
          ),
        ))),
      ),
    ));
    final label = find.text('Monthly consumption report');
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.textScaler.scale(14), 28);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(40));
    expect(find.byType(FittedBox), findsNothing);
    await tester.tap(find.byType(OutlinedButton));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
