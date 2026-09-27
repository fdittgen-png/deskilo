// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../application/template_workbook.dart';
import '../domain/workspace_feature.dart';
import 'feature_names.dart';

/// #1661 — the workbook's explanations and feature names in the reader's
/// language; keys, states and values stay technical English.
WorkbookLabels workbookLabels(AppLocalizations? l10n) {
  if (l10n == null) return WorkbookLabels.english();
  final byKey = {for (final f in WorkspaceFeature.values) f.dbKey: f};
  return WorkbookLabels(
    language: l10n.localeName,
    note: l10n.workbookNote,
    states: {
      'present': l10n.workbookStatePresent,
      'absent:inherit': l10n.workbookStateInherit,
      'absent:product_default': l10n.workbookStateDefault,
      'absent:required': l10n.workbookStateLocal,
      'unknown': l10n.workbookStateUnknown,
      'excluded': l10n.workbookStateExcluded,
    },
    feature: (key) => switch (byKey[key]) {
      final f? => featureName(l10n, f),
      null => key,
    },
    wide: l10n.workbookWide,
  );
}
