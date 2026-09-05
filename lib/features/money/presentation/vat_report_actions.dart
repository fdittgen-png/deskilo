// SPDX-License-Identifier: 0BSD
//
// #878 — the VAT report as user actions: the period's positions as the
// letter (quick view / save / share, through the workspace template
// like every document) and as the accountant's CSV.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/accounting_view.dart';
import '../domain/vat_regime.dart';
import '../domain/vat_report.dart';
import '../providers/money_providers.dart';
import 'invoice_actions.dart';
import 'report_actions.dart';
import 'report_layout_actions.dart';

/// The period's report from the invoices already loaded for the hub.
Future<VatReport> loadVatReport(
  WidgetRef ref, {
  required DateTime start,
  required DateTime end,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  final view = accountingView(
    await ref.read(invoicesProvider.future),
    ref.read(invoiceMatchesProvider).value ?? const {},
  );
  return buildVatReport(
    view.invoices,
    start: start,
    end: end,
    zeroCategory: vatRegimeFromWire(workspace?.vatRegime ?? 'not_subject')
        .taxCategoryCode,
  );
}

/// The Liquid data of the VAT report — the same legal mentions and
/// workspace identity every letter carries, plus the positions.
Map<String, Object?> vatReportData(
  BuildContext context,
  WidgetRef ref,
  VatReport report,
) {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.formatMinor(cents);
  final locale = Localizations.maybeLocaleOf(context)?.toString();
  final dateFormat = DateFormat.yMMMd(locale);
  String rate(double percent) => percent == percent.roundToDouble()
      ? '${percent.round()} %'
      : '${percent.toStringAsFixed(1)} %';
  final periodLabel = '${dateFormat.format(report.periodStart)} – '
      '${dateFormat.format(report.periodEnd)}';
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': '',
    'number': '',
    'period': periodLabel,
    'issued': dateFormat.format(ref.read(clockProvider).now()),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': money(report.grossCents),
    'charges': '',
    'payments': '',
    'net_total': money(report.netCents),
    'vat_total': money(report.vatCents),
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': report.vatCents > 0,
    'lines': const <Map<String, Object?>>[],
    'vat': const <Map<String, Object?>>[],
    'vat_period': periodLabel,
    'vat_period_net': money(report.netCents),
    'vat_period_vat': money(report.vatCents),
    'vat_period_gross': money(report.grossCents),
    'vat_positions': [
      for (final p in report.positions)
        {
          'number': p.number,
          'date': dateFormat.format(p.issuedAt),
          'customer': p.customer,
          'rate': rate(p.percent),
          'category': p.category,
          'net': money(p.netCents),
          'vat': money(p.vatCents),
          'gross': money(p.grossCents),
          'reverses': p.reversesNumber,
        },
    ],
    'vat_rate_totals': [
      for (final t in report.rateTotals)
        {
          'rate': rate(t.percent),
          'category': t.category,
          'count': '${t.documentCount}',
          'net': money(t.netCents),
          'vat': money(t.vatCents),
          'gross': money(t.grossCents),
        },
    ],
    ...legalMentionData(l10n, workspace),
  };
}

String _stem(VatReport report) {
  String d(DateTime x) =>
      '${x.year}${x.month.toString().padLeft(2, '0')}'
      '${x.day.toString().padLeft(2, '0')}';
  return 'vat-report-${d(report.periodStart)}-${d(report.periodEnd)}';
}

/// The letter: quick view / save / share.
Future<void> showVatReport(
  BuildContext context,
  WidgetRef ref, {
  required DateTime start,
  required DateTime end,
}) async {
  final l10n = AppLocalizations.of(context);
  final report = await loadVatReport(ref, start: start, end: end);
  if (!context.mounted) return;
  final data = vatReportData(context, ref, report);
  final rendered =
      renderLetterDoc(context, ref, docId: 'vat', data: data, language: '');
  final title = l10n?.reportDocVat ?? 'VAT report';
  await runReportActions(
    context,
    ref,
    keyPrefix: 'vat-report',
    logMessage: 'vat report pdf failed',
    render: () => rendered,
    buildPdf: () async {
      final pdf = await letterDocPdf(context, ref,
          report: rendered,
          title: title,
          layoutXml: letterLayoutXml(ref, docId: 'vat', language: ''),
          data: data);
      return (bytes: pdf.bytes, fileName: '${_stem(report)}.pdf');
    },
  );
}

/// The accountant's CSV, saved like every export.
Future<void> saveVatReportCsv(
  BuildContext context,
  WidgetRef ref, {
  required DateTime start,
  required DateTime end,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  final report = await loadVatReport(ref, start: start, end: end);
  if (!context.mounted) return;
  final csv =
      vatReportCsv(report, currency: workspace?.currencyCode ?? 'EUR');
  await savePdfToDownloads(context, ref,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: '${_stem(report)}.csv');
}
