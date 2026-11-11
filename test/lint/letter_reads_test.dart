// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3742 — a printed document reads the owner's template (and the dunning
// rules) before it is drawn: the synchronous accessors below answer only
// once that read has answered, and an unread template is never replaced
// by an empty one. A file that draws a letter therefore also awaits the
// read (`readDocumentPolicies(` or `readPolicy(`), or is a gatherer named
// below with the action that reads for it. Seven print actions had missed
// it when #3742 landed; this keeps the next one from forgetting.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The calls that read the template synchronously, directly or inside.
final _draws = RegExp(
  r'\b(invoicePdfTemplateFor|invoiceDueAt|renderLetterDoc|letterLayoutXml)\(',
);
final _reads = RegExp(r'\b(readDocumentPolicies|readPolicy)\(');

/// Files that draw without reading themselves, and who reads for them.
const _gatherers = {
  // Defines invoicePdfTemplateFor and invoiceDueAt; every print entry in it
  // runs under printOrRetry after readDocumentPolicies (document_policies).
  'lib/features/money/presentation/invoice_documents.dart':
      'its print entries call readDocumentPolicies first',
  // Defines renderLetterDoc and letterLayoutXml for the letter prints.
  'lib/features/money/presentation/report_layout_actions.dart':
      'each caller reads (this lint holds the callers)',
  // Built only from remindInvoice (invoice_followup_actions.dart).
  'lib/features/money/presentation/invoice_reminder_letter.dart':
      'remindInvoice reads the template with readPolicy',
  // Shows nothing until the watched template holds a value.
  'lib/features/money/presentation/widgets/setup_sample_invoice.dart':
      'watches invoicePdfTemplateProvider and waits for its value',
};

/// The files of [sources] that draw a letter without reading first.
List<String> unreadDraws(Map<String, String> sources) => [
  for (final e in sources.entries)
    if (_draws.hasMatch(e.value) &&
        !_reads.hasMatch(e.value) &&
        !_gatherers.containsKey(e.key))
      e.key,
];

void main() {
  test('a planted print action without the read is found', () {
    const planted = '''
Future<void> printIt(WidgetRef ref) async {
  final report = renderLetterDoc(context, ref, docId: 'status', data: {});
}
''';
    const reading = '''
Future<void> printIt(WidgetRef ref) async {
  await readDocumentPolicies(ref);
  final report = renderLetterDoc(context, ref, docId: 'status', data: {});
}
''';
    expect(unreadDraws({'lib/a.dart': planted, 'lib/b.dart': reading}), [
      'lib/a.dart',
    ]);
  });

  test('every file that draws a letter reads the template first', () {
    final sources = {
      for (final f in handWrittenDartFiles('lib'))
        f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
    };
    expect(
      unreadDraws(sources),
      isEmpty,
      reason:
          'await readDocumentPolicies(ref) (or readPolicy) before the letter '
          'is drawn, under printOrRetry where the action has no guard',
    );
    for (final gatherer in _gatherers.keys) {
      expect(sources.containsKey(gatherer), isTrue,
          reason: '$gatherer is gone: take it off the list');
    }
  });
}
