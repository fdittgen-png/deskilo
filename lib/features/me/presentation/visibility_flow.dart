// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How a person changes who sees a part of their account, wherever they do
// it: on this server's card or on a linked server's sheet.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../domain/visibility.dart';
import 'visibility_labels.dart';

/// Gives [field] a new audience: [pick] one, stop when it is [current] or
/// nothing was picked, ask first when it widens, [save] it guarded, then
/// [reread] what the write changed.
Future<void> chooseAudience(
  BuildContext context, {
  required VisibilityField field,
  required FieldAudience current,
  required Future<FieldAudience?> Function() pick,
  required Future<void> Function(FieldAudience) save,
  required VoidCallback reread,
}) async {
  final choice = await pick();
  if (choice == null || choice == current || !context.mounted) return;
  // Widening asks first, naming who will see it (#2211).
  if (choice.widens(current) &&
      !await _askBeforeWidening(context, field, choice)) {
    return;
  }
  if (!context.mounted) return;
  final ok = await runGuarded(
    context,
    domain: 'me',
    message: 'save visibility failed',
    errorText: context.l10n.visibilitySaveFailed,
    action: () => save(choice),
  );
  if (ok) reread();
}

/// #2211 — widening a field asks first, naming who will see it.
Future<bool> _askBeforeWidening(
  BuildContext context,
  VisibilityField field,
  FieldAudience choice,
) async {
  final l10n = context.l10n;
  final fieldName = visibilityFieldLabel(l10n, field);
  final who = audienceSummary(l10n, choice);
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(l10n.visibilityWidenConfirm(fieldName, who)),
          actions: [
            TextButton(
              key: const ValueKey('visibility-widen-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('visibility-widen-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.visibilityWidenAction),
            ),
          ],
        ),
      ) ??
      false;
}
