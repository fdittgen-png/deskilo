// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- a day's report on screen: the figures the server froze, said in words with the business's currency.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/till_day.dart';

/// Shows [report] full screen; closed with the back button or the close icon.
Future<void> showDayReport(BuildContext context, DayReport report, {required String currency}) => showDialog<void>(
  context: context,
  builder: (c) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(c.l10n.tillDayReportTitle(report.number)),
        leading: IconButton(key: const ValueKey('day-report-close'), tooltip: MaterialLocalizations.of(c).closeButtonTooltip, icon: const Icon(Icons.close), onPressed: () => Navigator.of(c).pop()),
      ),
      body: _DayReportView(report: report, currency: currency),
    ),
  ),
);

String _tenderName(AppLocalizations l10n, String kind) => switch (kind) {
  'cash' => l10n.tillDayTenderCash,
  'card' => l10n.paymentMethodCard,
  _ => l10n.tillDayTenderOther,
};

/// The report as a scrolling column of figures.
class _DayReportView extends StatelessWidget {
  const _DayReportView({required this.report, required this.currency});

  final DayReport report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final money = format.moneyIn(currency);
    String m(int minor) => money.formatMinor(minor);
    final title = Theme.of(context).textTheme.titleSmall;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const ValueKey('day-report'),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(l10n.tillDayReportDate(format.isoDay(report.businessDate)), style: Theme.of(context).textTheme.titleMedium),
            const FormGap(),
            Text(l10n.tillDaySessions, style: title),
            for (final s in report.sessions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.tillDaySessionLine(s.till, m(s.expectedMinor), m(s.countedMinor), m(s.differenceMinor)), key: ValueKey('day-session-${s.till}')),
                      if (s.differenceReason.isNotEmpty) Text(l10n.tillDaySessionReason(s.differenceReason)),
                      if (s.bankedMinor > 0) Text(l10n.tillDrawerClosedBanked(m(s.bankedMinor))),
                    ],
                  ),
                ),
              ),
            Text(l10n.tillDayDifferences(m(report.differencesMinor)), key: const ValueKey('day-differences')),
            const FormGap(),
            Text(l10n.tillDaySalesTotal(m(report.salesTotalMinor)), key: const ValueKey('day-sales'), style: title),
            if (report.firstReceipt.isNotEmpty) Text(l10n.tillDayReceiptRange(report.firstReceipt, report.lastReceipt)),
            if (report.salesByTender.isNotEmpty) ...[
              const FormGap.small(),
              Text(l10n.tillDayByTender, style: title),
              for (final e in report.salesByTender.entries) Text(l10n.tillDayAmountLine(_tenderName(l10n, e.key), m(e.value))),
            ],
            if (report.salesByRate.isNotEmpty) ...[
              const FormGap.small(),
              Text(l10n.tillDayByRate, style: title),
              for (final r in report.salesByRate) Text(l10n.tillDayRateLine(r.percent, m(r.netMinor), m(r.taxMinor), m(r.grossMinor))),
            ],
            const FormGap(),
            Text(l10n.tillDayPaidIn(m(report.paidInMinor))),
            Text(l10n.tillDayPaidOut(m(report.paidOutMinor))),
            if (report.depositsReturnedMinor != 0) Text(l10n.tillDayDepositsReturned(m(report.depositsReturnedMinor)), key: const ValueKey('day-deposits-returned')),
            if (report.refunds.isNotEmpty) Text(l10n.tillDayRefunds(m(report.refunds.values.fold(0, (a, b) => a + b)))),
            if (report.correctionsMinor != 0) Text(l10n.tillDayCorrections(m(report.correctionsMinor))),
            if (report.unresolvedCardMinor > 0) Text(l10n.tillDrawerClosedCard(m(report.unresolvedCardMinor))),
          ],
        ),
      ),
    );
  }
}
