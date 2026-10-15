// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in report_designer_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../navigation.dart';

/// Opens the editor page from the Invoices header.
Future<void> openEditor(WidgetTester tester) async {
  await tapInvoicingTool(tester, 'invoice-template-button');
  expect(find.byKey(const ValueKey('report-editor-page')), findsOneWidget);
}
