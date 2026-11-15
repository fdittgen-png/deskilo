// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the organisation's name, asked when it is made or renamed; and
// the question before a change every member of the organisation lives with.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';

/// Asks for the organisation's name.
class OrganisationNameDialog extends StatefulWidget {
  const OrganisationNameDialog({
    super.key,
    required this.title,
    required this.initial,
  });

  final String title;
  final String initial;

  @override
  State<OrganisationNameDialog> createState() => _OrganisationNameDialogState();
}

class _OrganisationNameDialogState extends State<OrganisationNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: AppTextField(
        key: const ValueKey('organisation-name-field'),
        controller: _name,
        label: l10n.organisationName,
        maxLength: 200,
        autofocus: true,
      ),
      actions: [
        TextButton(
          key: const ValueKey('organisation-name-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('organisation-name-save'),
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}

/// Asks before a change of the organisation: [text] says in one sentence
/// what happens; [action] goes ahead (in the destructive style when
/// [destructive]); Cancel is the default. True once the owner agrees.
Future<bool> confirmOrganisationChange(
  BuildContext context, {
  required String text,
  required String action,
  bool destructive = true,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialog) {
      final scheme = Theme.of(dialog).colorScheme;
      return AlertDialog(
        content: Text(text, key: const ValueKey('organisation-confirm-text')),
        actions: [
          TextButton(
            key: const ValueKey('organisation-confirm-cancel'),
            autofocus: true,
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('organisation-confirm-go'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return agreed ?? false;
}
