// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2861 — the workspace export's words in the reader's language.
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_export_labels.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_process.dart';
import 'feature_names.dart';
import 'process_names.dart';

/// The labels the workbook is written in, from [l10n].
ExportLabels workspaceExportLabels(AppLocalizations l10n) => ExportLabels(
  sheet: l10n.exportSheetName,
  column: l10n.exportColumnName,
  value: l10n.exportValueName,
  process: (key) => workspaceProcesses.any((p) => p.key == key)
      ? processLabel(l10n, key)
      : key,
  feature: (key) => switch (WorkspaceFeature.values
      .where((f) => f.dbKey == key)
      .firstOrNull) {
    final f? => featureName(l10n, f),
    null => key,
  },
  about: ExportAboutLabels(
    title: l10n.exportAboutTitle,
    workspace: l10n.exportAboutWorkspace,
    generatedOn: l10n.exportAboutGeneratedOn,
    timeZone: l10n.exportAboutTimeZone,
    currency: l10n.exportAboutCurrency,
    schema: l10n.exportAboutSchema,
    contents: l10n.exportAboutContents,
    sheet: l10n.exportAboutSheet,
    rows: l10n.exportAboutRows,
    machineCopy: l10n.exportAboutMachineCopy,
  ),
);
