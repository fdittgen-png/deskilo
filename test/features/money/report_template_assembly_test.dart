// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Saving the report editor writes the stored template with this
// session's edits folded in, and nothing else changed: documents,
// layouts, languages and the continuation strip it did not touch are
// kept exactly as they were.
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_template_assembly.dart';
import 'package:flutter_test/flutter_test.dart';

const _layout = '<report-layout/>';

const _stored = InvoicePdfTemplate(
  header: 'H',
  body: 'B',
  footer: 'F',
  continuation: 'page {{ page }}',
  proforma: ReportBands(header: 'PH'),
  extraDocs: {'agreement': ReportBands(body: 'AB')},
  layouts: {'statement': _layout},
  texts: {'greeting': 'Hello'},
  translations: {
    'fr': InvoicePdfTemplate(header: 'FR-H', texts: {'greeting': 'Bonjour'}),
    'nl': InvoicePdfTemplate(header: 'NL-H'),
  },
);

void main() {
  test('nothing edited saves the stored template unchanged', () {
    final saved = assembleReportTemplate(
      stored: _stored,
      drafts: const {},
      reminderLevels: 2,
    );
    expect(saved.toJson(), _stored.toJson());
  });

  test('editing one document keeps what the session never touched', () {
    final saved = assembleReportTemplate(
      stored: _stored,
      drafts: const {
        'invoice': ReportBands(header: 'H2', body: 'B', footer: 'F'),
      },
      reminderLevels: 2,
    );
    expect(saved.header, 'H2');
    // The band editors do not show the continuation strip, so a save
    // must not erase it (#872).
    expect(saved.continuation, 'page {{ page }}');
    // Another document's positioned layout, untouched this session.
    expect(saved.layoutFor('statement'), _layout);
    expect(saved.proforma.header, 'PH');
    expect(saved.extraDocs['agreement']?.body, 'AB');
    // An overlay in a language the editor does not offer.
    expect(saved.translations['nl']?.header, 'NL-H');
    expect(saved.translations['fr']?.header, 'FR-H');
    expect(saved.texts, {'greeting': 'Hello'});
  });

  test('drafts land on their document, language and reminder level', () {
    final saved = assembleReportTemplate(
      stored: _stored,
      drafts: const {
        'r2': ReportBands(body: 'second reminder'),
        'agreement': ReportBands(body: 'AB2'),
        'fr|proforma': ReportBands(header: 'FR-PH'),
        // Beyond the configured levels: no such document.
        'r3': ReportBands(body: 'ignored'),
      },
      reminderLevels: 2,
    );
    expect(saved.reminderBands(2)?.body, 'second reminder');
    expect(saved.reminderBands(1), isNull);
    expect(saved.reminderBands(3), isNull);
    expect(saved.extraDocs['agreement']?.body, 'AB2');
    expect(saved.translations['fr']?.proforma.header, 'FR-PH');
    expect(saved.translations['fr']?.header, 'FR-H');
    expect(saved.translations['fr']?.texts, {'greeting': 'Bonjour'});
  });

  test('layouts and texts: replaced, removed, per language', () {
    final saved = assembleReportTemplate(
      stored: _stored,
      drafts: const {},
      layoutDrafts: const {'statement': '', 'invoice': _layout},
      textDrafts: const {
        '': {'greeting': 'Hi'},
        'de': {'greeting': 'Hallo'},
      },
      reminderLevels: 0,
    );
    expect(saved.layoutFor('statement'), isNull);
    expect(saved.layoutFor('invoice'), _layout);
    expect(saved.texts, {'greeting': 'Hi'});
    expect(saved.translations['de']?.texts, {'greeting': 'Hallo'});
    expect(saved.translations['de']?.hasBands, isFalse);
  });

  test('a draft that brings its own continuation keeps it', () {
    final saved = assembleReportTemplate(
      stored: _stored,
      drafts: const {'invoice': ReportBands(header: 'H', continuation: 'C2')},
      reminderLevels: 0,
    );
    expect(saved.continuation, 'C2');
  });
}
