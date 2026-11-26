// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 -- the day report on the till's receipt printer, at the paper width the device's printer has: the figures the
// server froze, in the same words as on screen (the sessions and their differences, the takings by tender, the sales
// by tax rate, cash paid in and out), the day's sales as the total. Shown only where the business prints its receipts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/escpos_receipt.dart';
import '../../domain/till_day.dart';
import '../../domain/till_print_job.dart';
import '../../providers/till_printer_providers.dart';

String _tender(AppLocalizations l10n, String kind) => switch (kind) {
  'cash' => l10n.tillDayTenderCash,
  'card' => l10n.paymentMethodCard,
  _ => l10n.tillDayTenderOther,
};

/// What the day report [report] prints, in [currency].
ReceiptPrint dayReportPrint({required AppLocalizations l10n, required AppFormat fmt, required String business, required DayReport report, required String currency}) {
  final money = fmt.moneyIn(currency);
  String m(int minor) => money.formatMinor(minor);
  ReceiptPrintLine said(String text) => ReceiptPrintLine(label: text, amount: '');
  return ReceiptPrint(
    business: business,
    title: l10n.tillDayReportTitle(report.number),
    issuedAt: l10n.tillDayReportDate(fmt.isoDay(report.businessDate)),
    lines: [
      said(l10n.tillDaySessions),
      for (final s in report.sessions) said(l10n.tillDaySessionLine(s.till, m(s.expectedMinor), m(s.countedMinor), m(s.differenceMinor))),
      said(l10n.tillDayDifferences(m(report.differencesMinor))),
      if (report.firstReceipt.isNotEmpty) said(l10n.tillDayReceiptRange(report.firstReceipt, report.lastReceipt)),
      if (report.salesByRate.isNotEmpty) said(l10n.tillDayByRate),
      for (final r in report.salesByRate) said(l10n.tillDayRateLine(r.percent, m(r.netMinor), m(r.taxMinor), m(r.grossMinor))),
      said(l10n.tillDayPaidIn(m(report.paidInMinor))),
      said(l10n.tillDayPaidOut(m(report.paidOutMinor))),
      if (report.correctionsMinor != 0) said(l10n.tillDayCorrections(m(report.correctionsMinor))),
    ],
    taxLabel: l10n.tillReceiptTax,
    tax: m(report.salesByRate.fold(0, (a, r) => a + r.taxMinor)),
    totalLabel: l10n.tillPrintTotal,
    total: m(report.salesTotalMinor),
    tenders: [for (final e in report.salesByTender.entries) ReceiptPrintTender(label: _tender(l10n, e.key), amount: m(e.value))],
  );
}

/// Prints the day report on this device's printer; nothing where the business prints no receipts or no printer is set.
class DayReportPrintButton extends ConsumerWidget {
  const DayReportPrintButton({super.key, required this.report, required this.currency});

  final DayReport report;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(tillPrinterSettingsProvider).value;
    if (!ref.watch(tillPrinterOnProvider) || settings == null || !settings.configured) return const SizedBox.shrink();
    final l10n = context.l10n;
    return IconButton(
      key: const ValueKey('day-report-print'),
      tooltip: l10n.tillPrintReceipt,
      icon: const Icon(Icons.print_outlined),
      onPressed: () async {
        final job = tillPrintJob(
          receipt: dayReportPrint(l10n: l10n, fmt: appFormatOf(context), business: ref.read(currentWorkspaceProvider).value?.name ?? '', report: report, currency: currency),
          settings: settings,
        );
        try {
          await ref.read(receiptSenderProvider(settings)).send(job);
          if (context.mounted) AppSnack.info(context, l10n.tillPrinted);
        } on Object catch (e, st) {
          TraceLogger.instance.warn('money', 'the day report was not printed: $e', stackTrace: st);
          if (context.mounted) AppSnack.error(context, l10n.tillDayReportNotPrinted);
        }
      },
    );
  }
}
