// SPDX-License-Identifier: 0BSD
//
// #966 — the markup guide: every placeholder has a meaning and a topic,
// the guide is collapsed until asked for, and everything it offers
// inserts at the caret of the band last edited.
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/presentation/widgets/report_field_picker.dart';
import 'package:deskilo/features/money/presentation/widgets/report_markup_guide.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  test('every registry placeholder has a one-line meaning and a topic that '
      'is not the catch-all', () {
    for (final field in InvoicePdfTemplate.placeholders) {
      final meaning = reportFieldMeaning(field, null);
      expect(meaning, isNotEmpty);
      expect(meaning, isNot(field), reason: '$field reads as itself');
      expect(meaning.length, lessThan(90), reason: '$field: one line');
    }
    final legal = InvoicePdfTemplate.placeholders
        .where((f) => reportFieldGroup(f) == ReportFieldGroup.legal)
        .toList();
    expect(
        legal,
        unorderedEquals([
          'payment_terms',
          'payment_terms_source',
          'late_penalty',
          'recovery_indemnity',
          'escompte',
          'insurance',
          'special_mentions',
        ]),
        reason: 'only the legal mentions fall through to the last group');
    expect(reportFieldGroup('status_members'), ReportFieldGroup.loops);
    expect(reportFieldGroup('status_net'), ReportFieldGroup.status);
    expect(reportFieldGroup('iban'), ReportFieldGroup.bank);
    expect(reportFieldGroup('text.greeting'), ReportFieldGroup.texts);
  });

  test('insertMarkupAt replaces the selection and lands the caret after', () {
    const value = TextEditingValue(
      text: 'Hello world',
      selection: TextSelection(baseOffset: 6, extentOffset: 11),
    );
    final out = insertMarkupAt(value, '{{ member }}');
    expect(out.text, 'Hello {{ member }}');
    expect(out.selection, const TextSelection.collapsed(offset: 18));
    // No selection: appended.
    final appended = insertMarkupAt(const TextEditingValue(text: 'a'), '# b');
    expect(appended.text, 'a# b');
  });

  testWidgets('collapsed by default; expanded it inserts markup rows, '
      'snippets and picked fields', (tester) async {
    final inserted = <String>[];
    await tester.pumpWidget(_host(ReportMarkupGuide(onInsert: inserted.add)));
    await tester.pumpAndSettle();
    expect(find.text('Line markup'), findsNothing,
        reason: 'nothing overwhelms until the owner asks');

    await tester.tap(find.text('Placeholders and markup'));
    await tester.pumpAndSettle();
    expect(find.text('Line markup'), findsOneWidget);
    expect(find.text('A large title'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-markup-small')));
    expect(inserted.last, '> small text');

    await tester.ensureVisible(find.byKey(const ValueKey('report-snippet-if')));
    await tester.tap(find.byKey(const ValueKey('report-snippet-if')));
    expect(inserted.last, contains('{% if due_date != "" %}'));

    await tester.ensureVisible(
        find.byKey(const ValueKey('report-guide-insert-field')));
    await tester.tap(find.byKey(const ValueKey('report-guide-insert-field')));
    await tester.pumpAndSettle();
    expect(find.text("The document's number"), findsOneWidget,
        reason: 'the picker shows the meaning beside the name');
    await tester.enterText(
        find.byKey(const ValueKey('report-fields-search')), 'settlement');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-field-due_date')), findsOneWidget,
        reason: 'search matches the meaning, not only the name');
    expect(find.byKey(const ValueKey('report-field-number')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('report-field-due_date')));
    await tester.pumpAndSettle();
    expect(inserted.last, '{{ due_date }}');
  });
}
