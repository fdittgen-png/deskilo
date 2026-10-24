// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How a person changes who sees a part of their account, wherever they do
// it: on this server's card or on a linked server's sheet.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/visibility.dart';
import '../domain/visibility_write.dart';
import 'visibility_labels.dart';

/// Gives [field] a new audience: [pick] one (starting from the given
/// value), stop when it is the saved one or nothing was picked, ask first
/// when it widens, then [save] it guarded with the value it was read as —
/// [save] also rereads what its write changed. #2558 — with [spaceName],
/// the widening question also lists the chosen spaces added and removed.
///
/// #2558 — a home without the checked writer ([VisibilityUnsupported])
/// is named as such, not as a failed save; nothing is sent again.
///
/// #2558 C2 — a [VisibilityConflict] from [save] keeps the draft: the
/// person sees the value saved now beside their change and either keeps
/// the saved one or reviews the change against it (picked again from the
/// draft, asked again if it widens, sent with the new expected value).
Future<void> chooseAudience(
  BuildContext context, {
  required VisibilityField field,
  required FieldAudience current,
  required Future<FieldAudience?> Function(FieldAudience start) pick,
  required Future<void> Function(FieldAudience choice, FieldAudience expected)
      save,
  String Function(String id)? spaceName,
}) async {
  var expected = current;
  var start = current;
  while (true) {
    final choice = await pick(start);
    if (choice == null || choice == expected || !context.mounted) return;
    // Widening asks first, naming who will see it (#2211).
    if (choice.widens(expected) &&
        !await _askBeforeWidening(
            context, field, expected, choice, spaceName)) {
      return;
    }
    if (!context.mounted) return;
    VisibilityConflict? conflict;
    var unsupported = false;
    await runGuarded(
      context,
      domain: 'me',
      message: 'save visibility failed',
      errorText: context.l10n.visibilitySaveFailed,
      action: () async {
        try {
          await save(choice, expected);
        } on VisibilityConflict catch (e, st) {
          // trace-exempt: not a failure; the person reviews it below.
          debugPrint('visibility conflict: $e\n$st');
          conflict = e;
        } on VisibilityUnsupported catch (e, st) {
          // trace-exempt: named below; nothing was written or retried.
          debugPrint('visibility writer unsupported: $e\n$st');
          unsupported = true;
        }
      },
    );
    if (unsupported) {
      if (context.mounted) {
        AppSnack.error(context, context.l10n.visibilityUnsupported);
      }
      return;
    }
    final found = conflict;
    if (found == null || !context.mounted) return;
    final saved = found.current;
    if (!await _reviewConflict(context, found, choice) || saved == null) {
      return;
    }
    expected = saved;
    start = choice;
  }
}

/// #2558 C2 — the field changed before this write, or its outcome is not
/// known: what is saved now, beside the person's change. True reviews the
/// change again; false keeps the saved value.
Future<bool> _reviewConflict(
  BuildContext context,
  VisibilityConflict conflict,
  FieldAudience choice,
) async {
  final l10n = context.l10n;
  final saved = conflict.current;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          key: const ValueKey('visibility-conflict'),
          title: Text(conflict.unconfirmed
              ? l10n.visibilityUnconfirmedTitle
              : l10n.visibilityConflictTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved == null
                      ? l10n.visibilityConflictUnread
                      : l10n.visibilityConflictSaved(
                          audienceSummary(l10n, saved)),
                  key: const ValueKey('visibility-conflict-saved'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l10n.visibilityConflictYours(
                        audienceSummary(l10n, choice)),
                    key: const ValueKey('visibility-conflict-yours'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('visibility-conflict-keep'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.visibilityConflictKeep),
            ),
            if (saved != null)
              FilledButton(
                key: const ValueKey('visibility-conflict-review'),
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(l10n.visibilityConflictReview),
              ),
          ],
        ),
      ) ??
      false;
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
