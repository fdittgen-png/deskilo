// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/reconciliation_report.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/bank_reconciliation_words.dart';
import 'package:deskilo/features/money/presentation/letter_doc_pdf.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final words = bankReconciliationWordsOf(l10n);
  final report = BankReconciliationReport(
    statement: StoredBankStatement(
      id: 'statement',
      format: BankFileFormat.camt053,
      account: 'account',
      currency: 'EUR',
      from: DateTime.utc(2026),
      to: DateTime.utc(2026),
      lineCount: 0,
      openCount: 0,
    ),
    lines: const [],
    sourceUnavailableOrInaccessible: true,
    sourceAssociationUnavailable: true,
    unmappedSourceCount: 2,
  );
  final notices = bankReconciliationNotices(words, report);
  final data = <String, Object?>{
    'workspace': 'Test',
    'book_period': 'January',
    'book_rows': const [],
  };
  final designs = <String, ReportBands>{
    'default': defaultBandsForDoc('bank_reconciliation', l10n),
    'custom': const ReportBands(body: 'Custom statement difference: zero'),
  };
  for (final entry in designs.entries) {
    test('${entry.key} preview retains mandatory and conditional notices', () {
      final result = withBankReconciliationNotices(
        renderReportBands(bands: entry.value, data: data)!,
        notices,
      );
      final text = result.body.whereType<ReportText>().map((b) => b.text);
      expect(text, containsAll(notices));
      expect(
        notices,
        containsAll([
          l10n.bankReconCoverage,
          l10n.bankReconSeparateReads,
          l10n.bankReconFileArithmeticScope,
          l10n.bankReconBooksUnavailable,
          l10n.bankReconClearingUnavailable,
          l10n.bankReconOriginalUnavailable,
          l10n.bankReconSourceUnassociated,
          '${l10n.bankReconUnmappedCount}: 2',
        ]),
      );
    });
  }

  test('unavailable source reason survives a custom design', () {
    final unavailable = BankReconciliationReport(
      statement: report.statement,
      lines: const [],
      sourceIssue: BankSourceIssue.readUnavailable,
    );
    final result = withBankReconciliationNotices(
      renderReportBands(bands: designs['custom']!, data: data)!,
      bankReconciliationNotices(words, unavailable),
    );
    expect(
      result.body.whereType<ReportText>().map((b) => b.text),
      contains(l10n.bankReconReadUnavailable),
    );
  });

  testWidgets('band and positioned PDF retain a separate notice body', (
    tester,
  ) async {
    WidgetRef? captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final banded = renderReportBands(bands: designs['custom']!, data: data)!;
    const positioned =
        '<report-layout page="A4"><body>'
        '<text>Positioned custom statement difference: zero</text>'
        '</body></report-layout>';
    for (final name in ['default', 'custom', 'positioned']) {
      final rendered = name == 'default'
          ? renderReportBands(bands: designs[name]!, data: data)!
          : banded;
      final result = await tester.runAsync(
        () => letterPdfOf(
          captured!,
          (
            report: rendered,
            title: name,
            layoutXml: name == 'positioned' ? positioned : null,
            data: data,
            images: const {},
          ),
          pageLabel: 'Page',
          mandatoryNotices: notices,
        ),
      );
      expect(result!.bytes, isNotEmpty);
      final output = Platform.environment['BANK_NOTICE_PDF_DIR'];
      if (output != null) {
        final file = File('$output/$name.pdf')..writeAsBytesSync(result.bytes);
        final extracted = Process.runSync('pdftotext', [
          '-layout',
          file.path,
          '-',
        ]);
        expect(extracted.exitCode, 0, reason: '${extracted.stderr}');
        final text = '${extracted.stdout}'.replaceAll(RegExp(r'\s+'), ' ');
        for (final notice in notices) {
          expect(text, contains(notice));
        }
        if (name == 'positioned') {
          expect(
            text,
            contains('Positioned custom statement difference: zero'),
          );
        }
      }
    }
  });
}
