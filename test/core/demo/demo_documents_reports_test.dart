// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 (b) — nine document and report features of the reference business stop
// being switches: the owner's invoice template is what an issued Demo invoice
// prints with, the recipient sits in the envelope's window, a positioned layout
// is saved for one kind and exchanged as a file that comes back equal, a text of
// the report is changed and read in the printed footer, the designer saves an
// edited line, and the data export and the data report are made from the Demo's
// own rows.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/demo_documents_journeys.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('an issued invoice prints with the owner\'s template', () async {
    expect(await invoiceTemplateState(), isTrue);
  });

  test('the recipient sits in the window of the envelope', () async {
    expect(await addressWindowState(), isTrue);
  });

  test('the letter standard prints a statement as a letter', () async {
    expect(await letterStandardState(), isTrue);
  });

  test('a layout saved for one kind is the one that prints', () async {
    expect(await layoutState(), isTrue);
  });

  test('a design leaves as a file and comes back equal', () async {
    expect(await exchangeAction(), isTrue);
  });

  test('a text of the report is changed and read in the footer', () async {
    expect(await reportTextAction(), isTrue);
  });

  test('the designer saves an edited line', () async {
    expect(await designerEditAction(), isTrue);
  });

  test('the data export writes its file from the Demo\'s rows', () async {
    expect(await dataExportAction(), isTrue);
  });

  test('the data report holds the Demo\'s records', () async {
    expect(await dataReportState(), isTrue);
  });
}
