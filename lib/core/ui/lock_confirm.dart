// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The question a setup page asks before saving a value that a later act
// (the first invoice, the first recorded payment) fixes for good: [text]
// names what becomes permanent, Save goes ahead, Cancel saves nothing.
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';

/// True when the owner agrees to save; false when they cancel or dismiss.
Future<bool> confirmBeforeLock(BuildContext context, String text) async {
  final l10n = context.l10n;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.setupLockConfirmTitle),
      content: Text(text, key: const ValueKey('lock-confirm-body')),
      actions: [
        TextButton(
          key: const ValueKey('lock-confirm-cancel'),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('lock-confirm-save'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
