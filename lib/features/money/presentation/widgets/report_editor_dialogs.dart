// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's two questions (#822), moved out of
// invoice_template_sheet.dart so the editor holds its state and layout
// only.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// Presets, a reset and an imported design REPLACE a document's bands:
/// true when the person agrees.
Future<bool> confirmReportReplace(BuildContext context) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n.reportDesignerReplaceTitle,
      ),
      content: Text(
        l10n.reportDesignerReplaceBody,
      ),
      actions: [
        TextButton(
          key: const ValueKey('report-editor-dialogs-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('report-designer-replace-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.reportDesignerReplace),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Leaving the editor with unsaved work: true when the person discards.
Future<bool> confirmReportDiscard(BuildContext context) async {
  final l10n = context.l10n;
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.reportDesignerDiscardTitle),
      content: Text(
        l10n.reportDesignerDiscardBody,
      ),
      actions: [
        TextButton(
          key: const ValueKey('report-designer-keep-editing'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.reportDesignerKeepEditing),
        ),
        FilledButton(
          key: const ValueKey('report-designer-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.reportDesignerDiscard),
        ),
      ],
    ),
  );
  return leave ?? false;
}
