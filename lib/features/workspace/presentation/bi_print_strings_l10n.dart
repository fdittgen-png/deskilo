// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one place a report printout's words and formats are read out of the
// catalogue: the preview, the PDF and the data files' titles all take them
// from here, so no builder reaches into the ARB itself.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/bi_report_print.dart';
import '../domain/bi_report_snapshot.dart';
import '../domain/kpi_contract.dart';
import '../providers/operation_context_providers.dart';
import 'widgets/bi_module_section.dart' show biModuleViews;
import 'widgets/bi_toolbar.dart' show biDimensionName, biPeriodLabel;

/// The words and formats of a printout for the reader of [context], times
/// on the clock of the workspace's captured calendar (UTC while none is
/// captured, never the device's).
BiPrintStrings biPrintStringsFor(BuildContext context, WidgetRef ref) {
  final calendar = ref.read(workspaceContextProvider).value?.calendar;
  return biPrintStringsOf(
    context.l10n,
    Localizations.localeOf(context).toString(),
    wall: calendar?.wall ?? (at) => at.toUtc(),
  );
}

/// The words and formats of a printout in [locale]; [wall] gives an instant
/// as the workspace's clock reads it.
@visibleForTesting
BiPrintStrings biPrintStringsOf(
  AppLocalizations l10n,
  String locale, {
  required DateTime Function(DateTime instant) wall,
}) =>
    BiPrintStrings(
      workspace: l10n.biPrintWorkspace,
      report: l10n.biPrintReport,
      revision: (r) => l10n.biPrintRevision('$r'),
      unsaved: l10n.biPrintUnsaved,
      period: l10n.biPrintPeriod,
      dateBasis: l10n.biPrintDateBasis,
      currency: l10n.biPrintCurrency,
      filters: l10n.biPrintFilters,
      noFilters: l10n.biPrintNoFilters,
      computed: l10n.biPrintComputed,
      snapshot: l10n.biPrintSnapshot,
      complete: l10n.biPrintComplete,
      partial: l10n.biPrintPartial,
      management: l10n.biPrintManagement,
      leftOut: l10n.biPrintLeftOut,
      unknown: l10n.biPrintUnknown,
      qualifiedMark: l10n.biPrintQualified,
      failedMark: l10n.biPrintFailed,
      columns: [
        l10n.biPrintColPeriod,
        l10n.biPrintColValue,
        l10n.biPrintColBasis,
        l10n.biPrintColStatus,
      ],
      formats: BiPrintFormats(
        value: (f) => biSnapshotValueText(f, locale),
        number: (n) => NumberFormat.decimalPattern(locale).format(n),
        periodName: (p) => biPeriodLabel(p, l10n, locale),
        metricTitle: (id) => biMetricTitle(l10n, id),
        dateTime: (at) =>
            DateFormat.yMMMd(locale).add_Hm().format(wall(at)),
        dateBasis: (b) => _basis(l10n, b),
        coverage: (c) => _coverage(l10n, c),
        filter: (f) =>
            '${biDimensionName(l10n, f.dimension)} '
            '${f.operator == 'neq' ? '≠' : '='} ${f.value}',
      ),
    );

/// A metric's title in the reader's language; its id when the app has no
/// card for it.
String biMetricTitle(AppLocalizations l10n, String id) =>
    biModuleViews[id]?.title(l10n) ?? id;

/// A figure's value in its unit: a share as a percentage, an amount in its
/// own currency (never a default one).
@visibleForTesting
String biSnapshotValueText(BiSnapshotFigure f, String locale) {
  final v = f.value;
  if (v == null) return '—';
  return switch (f.metric.unit) {
    'percent' => NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: 1,
    ).format(v),
    'currency_minor' when f.currency.isNotEmpty => MoneyFormat(
      f.currency,
      locale: locale,
    ).formatMinor(v.toInt()),
    _ => NumberFormat.decimalPattern(locale).format(v),
  };
}

String _basis(AppLocalizations l10n, KpiDateBasis b) => switch (b) {
  KpiDateBasis.reservationTime => l10n.biBasisReservationTime,
  KpiDateBasis.invoiceMonth => l10n.biBasisInvoiceMonth,
  KpiDateBasis.paymentMatchedAt => l10n.biBasisPaymentMatchedAt,
  KpiDateBasis.paymentReportedPaid => l10n.biBasisPaymentReportedPaid,
  KpiDateBasis.documentDate => l10n.biBasisDocumentDate,
  KpiDateBasis.occurrenceDue => l10n.biBasisOccurrenceDue,
  KpiDateBasis.bookValuePeriod => l10n.biBasisBookValuePeriod,
  KpiDateBasis.periodEnd => l10n.biBasisPeriodEnd,
  KpiDateBasis.currentState => l10n.biBasisCurrentState,
};

String _coverage(AppLocalizations l10n, KpiCoverage c) => switch (c) {
  KpiCoverage.recordedHistory => l10n.biCoverageRecordedHistory,
  KpiCoverage.currentRecords => l10n.biCoverageCurrentRecords,
  KpiCoverage.confirmedValues => l10n.biCoverageConfirmedValues,
  KpiCoverage.currentStateOnly => l10n.biCoverageCurrentStateOnly,
};
