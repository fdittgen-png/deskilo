// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Correct a message you wrote (0382): the words in a field, nothing else.
Future<String?> showEditMessageDialog(BuildContext context, String initial) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n?.messengerEditTitle ?? 'Edit message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('message-edit-field'),
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.messengerEditWindow ??
                'A message can be corrected for 15 minutes after it was sent.',
            style: Theme.of(dialog).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('message-edit-cancel'),
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('message-edit-save'),
          onPressed: () => Navigator.of(dialog).pop(controller.text),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
}
