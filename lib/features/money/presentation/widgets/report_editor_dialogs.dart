// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's two questions (#822), moved out of
// invoice_template_sheet.dart so the editor holds its state and layout
// only.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Presets, a reset and an imported design REPLACE a document's bands:
/// true when the person agrees.
Future<bool> confirmReportReplace(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n?.reportDesignerReplaceTitle ?? 'Replace the current layout?',
      ),
      content: Text(
        l10n?.reportDesignerReplaceBody ??
            'The bands of this document are replaced. Undo brings them back.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('report-designer-replace-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.reportDesignerReplace ?? 'Replace'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Leaving the editor with unsaved work: true when the person discards.
Future<bool> confirmReportDiscard(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.reportDesignerDiscardTitle ?? 'Leave without saving?'),
      content: Text(
        l10n?.reportDesignerDiscardBody ??
            'Your changes to the templates are not saved.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('report-designer-keep-editing'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.reportDesignerKeepEditing ?? 'Keep editing'),
        ),
        FilledButton(
          key: const ValueKey('report-designer-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.reportDesignerDiscard ?? 'Discard'),
        ),
      ],
    ),
  );
  return leave ?? false;
}
