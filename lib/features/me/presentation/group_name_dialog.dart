// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';

/// Asks for the name of one of my groups; pops the name typed, or null.
class GroupNameDialog extends StatefulWidget {
  const GroupNameDialog({super.key, this.initial = ''});

  /// The current name when renaming; empty for a new group.
  final String initial;

  @override
  State<GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<GroupNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.meGroupName),
      content: TextField(
        key: const ValueKey('me-group-name-field'),
        controller: _name,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          key: const ValueKey('me-group-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('me-group-save'),
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
