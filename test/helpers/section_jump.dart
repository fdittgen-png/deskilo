// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — a section pill of a long form (SectionJumpBar). On a phone the
// pills that do not fit sit behind the bar's "more" button; this opens
// that menu first when the pill is not on the row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapSection(WidgetTester tester, String key) async {
  if (find.byKey(ValueKey(key)).evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('section-jump-more')).first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ValueKey(key)).last);
}
