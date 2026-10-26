// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The words of the report editor for the registry's values: a visual kind,
// a figure's unit, date basis and coverage, and every reason a choice is
// refused — each said in the reader's language, never a wire name.
import '../../../../l10n/app_localizations.dart';
import '../../application/report_editor/bi_report_commands.dart';
import '../../domain/bi_report_rules.dart';
import '../../domain/bi_report_visual.dart';
import '../../domain/kpi_descriptor.dart';

String biVisualKindLabel(AppLocalizations l10n, BiVisualType type) =>
    switch (type) {
      BiVisualType.kpi => l10n.biEditorKindKpi,
      BiVisualType.line => l10n.biEditorKindLine,
      BiVisualType.bar => l10n.biEditorKindBar,
      BiVisualType.stackedBar => l10n.biEditorKindStackedBar,
      BiVisualType.table => l10n.biEditorKindTable,
      BiVisualType.text => l10n.biEditorKindText,
    };

String biUnitLabel(AppLocalizations l10n, String unit) => switch (unit) {
  'percent' => l10n.biEditorUnitPercent,
  'currency_minor' => l10n.biEditorUnitAmount,
  _ => l10n.biEditorUnitCount,
};

String biDateBasisLabel(AppLocalizations l10n, KpiDateBasis basis) =>
    switch (basis) {
      KpiDateBasis.reservationTime => l10n.biEditorBasisReservationTime,
      KpiDateBasis.invoiceMonth => l10n.biEditorBasisInvoiceMonth,
      KpiDateBasis.paymentMatchedAt => l10n.biEditorBasisPaymentMatched,
      KpiDateBasis.paymentReportedPaid => l10n.biEditorBasisReportedPaid,
      KpiDateBasis.documentDate => l10n.biEditorBasisDocumentDate,
      KpiDateBasis.occurrenceDue => l10n.biEditorBasisOccurrenceDue,
      KpiDateBasis.bookValuePeriod => l10n.biEditorBasisBookValue,
      KpiDateBasis.periodEnd => l10n.biEditorBasisPeriodEnd,
      KpiDateBasis.currentState => l10n.biEditorBasisCurrentState,
    };

String biCoverageLabel(AppLocalizations l10n, KpiCoverage coverage) =>
    switch (coverage) {
      KpiCoverage.recordedHistory => l10n.biEditorCoverageHistory,
      KpiCoverage.currentRecords => l10n.biEditorCoverageCurrentRecords,
      KpiCoverage.confirmedValues => l10n.biEditorCoverageConfirmed,
      KpiCoverage.currentStateOnly => l10n.biEditorCoverageTodayOnly,
    };

String biBindingRefusalText(AppLocalizations l10n, BiBindingRefusal r) =>
    switch (r) {
      BiBindingRefusal.unknownMetric => l10n.biEditorRefusedUnknown,
      BiBindingRefusal.noHistory => l10n.biEditorRefusedNoHistory,
      BiBindingRefusal.noGrouping => l10n.biEditorRefusedNoGrouping,
      BiBindingRefusal.notAdditive => l10n.biEditorRefusedNotAdditive,
      BiBindingRefusal.dimensionUnsupported => l10n.biEditorRefusedDimension,
      BiBindingRefusal.formatUnit => l10n.biEditorRefusedFormat,
      BiBindingRefusal.sortNeedsGrouping => l10n.biEditorRefusedSort,
      BiBindingRefusal.axisNeedsLine => l10n.biEditorRefusedAxis,
      BiBindingRefusal.textHasNoMetric => l10n.biEditorRefusedText,
    };

String biEditRefusalText(AppLocalizations l10n, BiEditRefusal r) => switch (r) {
  BiEditRefusal.limit => l10n.biEditorRefusedLimit,
  BiEditRefusal.lastPage => l10n.biEditorRefusedLastPage,
  BiEditRefusal.widens => l10n.biEditorRefusedWidens,
  BiEditRefusal.missing => l10n.biEditorRefusedMissing,
  BiEditRefusal.invalidText => l10n.biEditorRefusedTextLength,
};
