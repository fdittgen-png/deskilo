// SPDX-License-Identifier: 0BSD
//
// #880 — the owner's texts: stored on the template per language,
// merged like documents, seeded so an unknown key is EMPTY (guards stay
// false), escaped in layouts, offered by the field picker, edited in
// the panel.
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/domain/report_layout_file.dart';
import 'package:deskilo/features/money/presentation/widgets/report_field_picker.dart';
import 'package:deskilo/features/money/presentation/widgets/report_texts_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the template', () {
    const base = InvoicePdfTemplate(
      header: 'h',
      texts: {'greeting': 'Merci de votre confiance', 'note': 'Base note'},
    );

    test('texts survive JSON, and none are written when there are none', () {
      final back = InvoicePdfTemplate.fromJson(base.toJson());
      expect(back.texts, base.texts);
      expect(const InvoicePdfTemplate(header: 'h').toJson(),
          isNot(contains(InvoicePdfTemplate.keyTexts)));
    });

    test('every rebuild carries the texts through', () {
      expect(base.withReminder(1, ReportBands.empty).texts, base.texts);
      expect(base.withTranslation('de', InvoicePdfTemplate.empty).texts,
          base.texts);
      expect(base.copyWith(layouts: const {}).texts, base.texts);
      expect(base.copyWith(texts: const {'x': 'y'}).texts, {'x': 'y'});
    });

    test('a language overlay\'s non-empty value wins; empty falls back', () {
      final t = base.withTranslation(
        'de',
        const InvoicePdfTemplate(texts: {'greeting': 'Vielen Dank', 'note': ''}),
      );
      expect(t.forLocale('de').texts,
          {'greeting': 'Vielen Dank', 'note': 'Base note'});
      expect(t.forLocale('fr').texts, base.texts,
          reason: 'no overlay → the default language');
    });
  });

  group('rendering', () {
    test('a band prints the text, and an unknown key is EMPTY — the guard '
        'stays false', () {
      final report = renderReportBands(
        bands: const ReportBands(
          body: '[{{ text.greeting }}]'
              '{% if text.missing != "" %}LEAK{% endif %}'
              '{% if text.greeting != "" %}OK{% endif %}',
        ),
        data: withOwnerTexts(const {}, const {'greeting': 'Merci'}),
      );
      final text = report!.body.map(_blockText).join();
      expect(text, contains('[Merci]'));
      expect(text, contains('OK'));
      expect(text, isNot(contains('LEAK')));
    });

    test('without any texts passed, text.* is still seeded empty', () {
      final report = renderReportBands(
        bands: const ReportBands(
            body: 'A{% if text.note != "" %}LEAK{% endif %}B'),
        data: const {},
      );
      expect(report!.body.map(_blockText).join(),
          allOf(contains('A'), contains('B'), isNot(contains('LEAK'))));
    });

    test('a layout XML-escapes the text so an ampersand cannot break it',
        () {
      final doc = renderLayoutDocument(
        '<report-layout page="A4"><body><text>{{ text.note }}</text></body></report-layout>',
        withOwnerTexts(const {}, const {'note': 'Smith & Sons <b>'}),
      );
      expect(doc, isNotNull);
    });
  });

  test('the exchange file carries the texts of its language, and reads '
      'them back', () {
    final content = buildReportLayoutFile(
      kind: reportKindById('invoice')!,
      language: 'de',
      workspaceName: 'Demo',
      layoutXml:
          '<report-layout page="A4"><body><text>{{ text.greeting }}</text></body></report-layout>',
      exportedAt: DateTime.utc(2026, 9, 5),
      texts: const {'greeting': 'Vielen Dank & bis bald'},
    );
    expect(content, contains('<texts>'));
    final parsed = parseReportLayoutFile(content);
    expect(parsed.texts, {'greeting': 'Vielen Dank & bis bald'});
    expect(parsed.language, 'de');
  });

  test('the field picker files text.<key> under its own group', () {
    expect(reportFieldGroup('text.greeting'), ReportFieldGroup.texts);
    expect(reportFieldMarkup('text.greeting'), '{{ text.greeting }}');
    expect(reportFieldGroupName(ReportFieldGroup.texts, null), 'Your texts');
  });

  group('the panel', () {
    testWidgets('adds a key, edits its value, removes it', (tester) async {
      var current = <String, String>{'greeting': 'Merci'};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ReportTextsPanel(
                language: '',
                texts: current,
                inherited: const {},
                onChanged: (t) => setState(() => current = t),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('report-texts-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-text-greeting')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('report-texts-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('report-texts-key-field')), 'Bad Key');
      await tester.tap(find.byKey(const ValueKey('report-texts-key-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('letters, digits'), findsOneWidget,
          reason: 'a key must be a Liquid identifier');
      await tester.enterText(
          find.byKey(const ValueKey('report-texts-key-field')), 'season_note');
      await tester.tap(find.byKey(const ValueKey('report-texts-key-confirm')));
      await tester.pumpAndSettle();
      expect(current.keys, contains('season_note'));

      await tester.enterText(
          find.byKey(const ValueKey('report-text-season_note')), 'Joyeux Noël');
      expect(current['season_note'], 'Joyeux Noël');

      await tester.tap(find.byKey(const ValueKey('report-text-remove-greeting')));
      await tester.pumpAndSettle();
      expect(current.containsKey('greeting'), isFalse);
    });

    testWidgets('an overlay shows the default language as the hint',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReportTextsPanel(
            language: 'de',
            texts: const {},
            inherited: const {'greeting': 'Merci'},
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('report-texts-expand')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('report-text-greeting')));
      expect(field.decoration?.hintText, 'Merci');
      expect(field.decoration?.helperText, 'Default language');
    });
  });
}

String _blockText(ReportBlock block) => switch (block) {
      ReportHeading(:final text) => text,
      ReportSubheading(:final text) => text,
      ReportText(:final text) => text,
      ReportMuted(:final text) => text,
      _ => '',
    };
