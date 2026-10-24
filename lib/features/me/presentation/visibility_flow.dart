// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How a person changes who sees a part of their account, wherever they do
// it: on this server's card or on a linked server's sheet.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../domain/visibility.dart';
import 'visibility_labels.dart';

/// Gives [field] a new audience: [pick] one, stop when it is [current] or
/// nothing was picked, ask first when it widens, then [save] it guarded —
/// [save] also rereads what its write changed. #2558 — with [spaceName],
/// the widening question also lists the chosen spaces added and removed.
Future<void> chooseAudience(
  BuildContext context, {
  required VisibilityField field,
  required FieldAudience current,
  required Future<FieldAudience?> Function() pick,
  required Future<void> Function(FieldAudience) save,
  String Function(String id)? spaceName,
}) async {
  final choice = await pick();
  if (choice == null || choice == current || !context.mounted) return;
  // Widening asks first, naming who will see it (#2211).
  if (choice.widens(current) &&
      !await _askBeforeWidening(context, field, current, choice, spaceName)) {
    return;
  }
  if (!context.mounted) return;
  await runGuarded(
    context,
    domain: 'me',
    message: 'save visibility failed',
    errorText: context.l10n.visibilitySaveFailed,
    action: () => save(choice),
  );
}

/// #2211 — widening a field asks first, naming who will see it.
Future<bool> _askBeforeWidening(
  BuildContext context,
  VisibilityField field,
  FieldAudience current,
  FieldAudience choice,
  String Function(String id)? spaceName,
) async {
  final l10n = context.l10n;
  final fieldName = visibilityFieldLabel(l10n, field);
  final who = audienceSummary(l10n, choice);
  final diff = FieldAudience.spacesDiff(current, choice);
  String names(List<String> ids) => ids.map(spaceName!).join(', ');
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.visibilityWidenConfirm(fieldName, who)),
                if (spaceName != null && diff.added.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      l10n.visibilityWidenAdded(names(diff.added)),
                      key: const ValueKey('visibility-widen-added'),
                    ),
                  ),
                if (spaceName != null && diff.removed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      l10n.visibilityWidenRemoved(names(diff.removed)),
                      key: const ValueKey('visibility-widen-removed'),
                    ),
                  ),
              ],
            ),
          ),
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
