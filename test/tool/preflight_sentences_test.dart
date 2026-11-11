// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3752 -- a changed sentence lists the tests that still assert its old text.
// The first case is the change that went red on 11 Nov 2026: a sentence got
// its plural forms, and two widget tests in another folder still expected
// "1 rows in 1 tables".
import 'package:flutter_test/flutter_test.dart';

import '../../tool/preflight/affected_tests.dart';

const _key = 'workspaceXmlImportPreviewConfiguration';
const _before =
    'Configuration: {settings} settings, {rows} rows in {tables} tables';
const _after =
    'Configuration: {settings, plural, =1{1 setting} other{{settings} '
    'settings}}, {rows, plural, =1{1 row} other{{rows} rows}} in '
    '{tables, plural, =1{1 table} other{{tables} tables}}';

const _sources = {
  'test/features/workspace/workspace_xml_import_screen_test.dart':
      "expect(find.textContaining('Configuration: 2 settings, 1 rows in 1 "
      "tables'), findsOneWidget);",
  'test/features/workspace/workspace_settings_screen_test.dart':
      'await pumpScreen(tester, settings, tables: 2);',
  'test/features/money/invoice_list_test.dart':
      "expect(find.text('3 open invoices'), findsOneWidget);",
};

void main() {
  test('the change of 11 Nov lists the test that asserted the old sentence',
      () {
    expect(
      testsOfChangedSentences({_key: _before}, {_key: _after}, _sources),
      {'test/features/workspace/workspace_xml_import_screen_test.dart'},
    );
  });

  test('a sentence that did not change lists nothing', () {
    expect(
      testsOfChangedSentences({_key: _before}, {_key: _before}, _sources),
      isEmpty,
    );
  });

  test('a removed sentence is searched like a changed one', () {
    expect(
      testsOfChangedSentences({_key: _before}, const {}, _sources),
      {'test/features/workspace/workspace_xml_import_screen_test.dart'},
    );
  });

  test('one reworded word is not searched: it is an identifier elsewhere', () {
    expect(literalPieces('settings,'), isEmpty);
    expect(
      testsOfChangedSentences(
        {'label': 'settings, {count}'},
        {'label': 'options, {count}'},
        _sources,
      ),
      isEmpty,
    );
  });

  test('placeholders and plural syntax give their text, never their names',
      () {
    expect(
      literalPieces(
        '{customerName} owes {count, plural, =1{one invoice} '
        'other{{count} open invoices}} since {issuedOn}',
      ),
      {'one invoice', 'open invoices'},
    );
    expect(literalPieces(_before), {'rows in'});
  });

  test('a piece the new text keeps is not searched', () {
    expect(
      testsOfChangedSentences(
        {'a': 'Paid in full. {count} open invoices'},
        {'a': 'Settled. {count} open invoices'},
        _sources,
      ),
      isEmpty,
      reason: '"open invoices" is still said, so the test that expects it '
          'is not listed; "Paid in full." is gone and no test holds it',
    );
  });

  test('descriptions and unbalanced text never throw', () {
    expect(
      testsOfChangedSentences(
        {
          '@a': {'description': 'rows in a table'},
          'a': 'broken {count, plural, =1{one row in',
        },
        {'a': 'fixed'},
        _sources,
      ),
      isEmpty,
    );
  });
}
