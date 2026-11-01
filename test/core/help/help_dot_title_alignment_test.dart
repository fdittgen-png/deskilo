// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3068 — a one-line row title and its help symbol share one centre line
// (the text no longer rides the top of the 48 dp target), and a title that
// wraps keeps the symbol with its first line (#1185).
import 'package:deskilo/core/help/help_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('a single-line title is centred on its help symbol',
      (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: ListTile(title: HelpDotTitle('Status', 'topic')),
      ),
    );
    await tester.pump();
    final text = tester.getCenter(find.text('Status')).dy;
    final dot = tester.getCenter(find.byKey(const ValueKey('help-dot-topic'))).dy;
    expect(text, closeTo(dot, 0.5));
  });

  testWidgets('a wrapped title keeps the symbol with its first line',
      (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: SizedBox(
          width: 140,
          child: ListTile(
            title: HelpDotTitle('A title long enough to wrap onto lines ' * 3, 'topic'),
          ),
        ),
      ),
    );
    await tester.pump();
    final title = tester.getRect(find.textContaining('A title'));
    final dot = tester.getRect(find.byKey(const ValueKey('help-dot-topic')));
    expect(title.height, greaterThan(dot.height));
    expect(dot.top, closeTo(title.top, 1));
  });
}
