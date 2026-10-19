// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// Correct a message you wrote (0382): the words in a field, nothing else.
Future<String?> showEditMessageDialog(BuildContext context, String initial) {
  final l10n = context.l10n;
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(scrollable: true,
      title: Text(l10n.messengerEditTitle),
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
            l10n.messengerEditWindow,
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
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );
}
