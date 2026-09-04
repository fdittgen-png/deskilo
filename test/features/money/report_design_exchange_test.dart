// SPDX-License-Identifier: 0BSD
//
// #864 — a report design leaves as a file that explains itself and comes
// back the same way. The refusals matter as much as the happy path: a
// design silently retargeted at the wrong report rewrites a document
// nobody asked about.
import 'dart:convert';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_design_file.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:flutter_test/flutter_test.dart';

const _invoice = ReportKind(id: 'invoice', slot: ReportRootSlot());
const _statement = ReportKind(id: 'statement', slot: ReportStatementSlot());

const _bands = ReportBands(
  header: '# {{ workspace }}',
  body: '{% for line in lines %}{{ line }}{% endfor %}',
  footer: '> {{ payment_terms }}',
);

String _file({
  ReportKind kind = _invoice,
  String language = '',
  ReportBands bands = _bands,
}) =>
    buildReportDesignFile(
      kind: kind,
      language: language,
      workspaceName: 'My Space',
      bands: bands,
      exportedAt: DateTime.utc(2026, 9, 4, 12),
    );

void main() {
  group('the file explains itself', () {
    test('it carries the design, the report it belongs to, and how to '
        'edit it', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      expect(json['schema'], 'deskilo.report-design');
      expect(json['version'], 1);
      expect(json['kind'], 'invoice');
      expect(json['design'], {
        'header': _bands.header,
        'body': _bands.body,
        'footer': _bands.footer,
      });
      final howTo = json['howToEdit'] as Map<String, dynamic>;
      expect(howTo['bands'], isA<Map>());
      expect(howTo['markup'], isA<Map>());
      expect(howTo['placeholders'], contains('payment_terms'));
      expect(howTo['summary'], contains('import the file back'));
    });

    test('it advertises exactly the placeholders the renderer knows', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      final howTo = json['howToEdit'] as Map<String, dynamic>;
      expect((howTo['placeholders'] as List).cast<String>(),
          InvoicePdfTemplate.placeholders);
    });

    test('it reads as source: indented, newline-terminated', () {
      final content = _file();
      expect(content.endsWith('\n'), isTrue);
      expect(content, contains('\n  "kind": "invoice"'));
    });
  });

  group('round trip', () {
    test('export, import, export is byte identical', () {
      final first = _file(language: 'fr');
      final parsed = parseReportDesignFile(first, expectedKind: _invoice);
      final second = buildReportDesignFile(
        kind: _invoice,
        language: parsed.language,
        workspaceName: 'My Space',
        bands: parsed.bands,
        exportedAt: DateTime.utc(2026, 9, 4, 12),
      );
      expect(second, first);
    });

    test('editing the instructions changes nothing — they are output '
        'only', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      json['howToEdit'] = {'nonsense': true};
      final tampered = jsonEncode(json);
      final parsed = parseReportDesignFile(tampered, expectedKind: _invoice);
      expect(parsed.bands.header, _bands.header);
      expect(parsed.bands.body, _bands.body);
      expect(parsed.bands.footer, _bands.footer);
    });

    test('an empty design survives, because an empty band is a choice', () {
      final parsed = parseReportDesignFile(
          _file(bands: ReportBands.empty), expectedKind: _invoice);
      expect(parsed.bands.hasBands, isFalse);
    });
  });

  group('what import refuses, and why', () {
    void refuses(String content, ReportDesignError expected,
        {ReportKind? into = _invoice}) {
      expect(
        () => parseReportDesignFile(content, expectedKind: into),
        throwsA(isA<ReportDesignException>()
            .having((e) => e.error, 'error', expected)),
      );
    }

    test('not JSON', () => refuses('{not json', ReportDesignError.malformed));

    test('JSON but not an object',
        () => refuses('[1,2,3]', ReportDesignError.malformed));

    test('somebody else\'s JSON', () {
      refuses('{"hello":"world"}', ReportDesignError.notADesignFile);
    });

    test('a newer schema is refused rather than guessed at', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      json['version'] = 99;
      refuses(jsonEncode(json), ReportDesignError.unsupportedVersion);
    });

    test('a design for a report this workspace does not have', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      json['kind'] = 'not_a_report';
      refuses(jsonEncode(json), ReportDesignError.unknownKind);
    });

    test('a design for ANOTHER report is never silently retargeted', () {
      refuses(_file(kind: _statement), ReportDesignError.wrongKind);
    });

    test('a design whose bands are not strings', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      json['design'] = {'header': 42};
      refuses(jsonEncode(json), ReportDesignError.invalidDesign);
    });

    test('a design block that is not an object', () {
      final json = jsonDecode(_file()) as Map<String, dynamic>;
      json['design'] = 'nope';
      refuses(jsonEncode(json), ReportDesignError.invalidDesign);
    });

    test('a reminder design is refused when dunning offers no levels', () {
      const reminder = ReportKind(id: 'r1', slot: ReportReminderSlot(1));
      expect(
        () => parseReportDesignFile(_file(kind: reminder), reminderLevels: 0),
        throwsA(isA<ReportDesignException>()
            .having((e) => e.error, 'error', ReportDesignError.unknownKind)),
      );
      // ...and accepted when they exist.
      expect(
        parseReportDesignFile(_file(kind: reminder), reminderLevels: 2).kindId,
        'r1',
      );
    });
  });

  group('the file name', () {
    test('names the report, the language and the workspace, slugged', () {
      expect(
        reportDesignFileName(
            kindId: 'invoice', language: 'fr', workspaceName: 'My Space'),
        'deskilo-report-invoice-fr-my-space.json',
      );
    });

    test('omits the language for a base design', () {
      expect(
        reportDesignFileName(
            kindId: 'statement', language: '', workspaceName: 'Espace Café'),
        'deskilo-report-statement-espace-caf.json',
      );
    });

    test('a hostile workspace name cannot escape the directory', () {
      final name = reportDesignFileName(
          kindId: 'invoice', language: '', workspaceName: '../../etc/passwd');
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('..')));
    });
  });
}
