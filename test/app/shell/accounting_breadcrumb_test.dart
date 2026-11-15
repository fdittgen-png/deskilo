// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4066 — the breadcrumb names each level once. "Accounting & VAT" is both a
// group of the sidebar and its entry: the accounting page reads "Accounting
// & VAT", its exports page "Accounting & VAT › Exports", never the name
// twice. A group whose entry has another name keeps both.
import 'package:deskilo/app/shell/desk_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart';
import '../../helpers/screens/desk_calendar.dart' show goTo;

List<String> _crumbs(WidgetTester tester) => [
  for (final c
      in tester.widget<DeskBreadcrumb>(find.byType(DeskBreadcrumb)).crumbs)
    c.label,
];

void main() {
  testWidgets('the exports page names Accounting & VAT once', (tester) async {
    await pumpDemo(tester, openHub: false, size: const Size(1440, 900));
    await goTo(tester, '/money/accounting/exports');
    expect(_crumbs(tester), ['Accounting & VAT', 'Exports']);
    await goTo(tester, '/money/accounting');
    expect(_crumbs(tester), ['Accounting & VAT']);
  });

  testWidgets('a group whose entry has another name keeps both', (
    tester,
  ) async {
    await pumpDemo(tester, openHub: false, size: const Size(1440, 900));
    await goTo(tester, '/vat-declarations');
    expect(_crumbs(tester).take(2), ['Accounting & VAT', 'VAT declaration']);
  });
}
