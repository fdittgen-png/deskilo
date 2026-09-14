// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Ask for one line of text — the editor's "name this room" dialog.
///
/// Returns the trimmed answer, or null when dismissed or cancelled; the
/// caller decides whether an empty answer means anything.
///
/// Extracted from `level_canvas_screen.dart` (#1235), which had grown
/// past its length budget: a dialog that names a thing is not part of
/// what a canvas screen does.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
}
