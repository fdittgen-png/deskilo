// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the contact person a SAF-T Financial file names in its header
// (Company/Contact, mandatory in every profile; Luxembourg also requires a
// telephone). Asked at export, like DATEV's adviser numbers: it is a fact of
// this file, written into it and nowhere else.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/saf_t_financial.dart';

/// The contact, or null when the person backed out.
Future<SafTContact?> showSafTContactDialog(BuildContext context) =>
    showDialog<SafTContact>(
      context: context,
      builder: (context) => const _SafTContactDialog(),
    );

class _SafTContactDialog extends StatefulWidget {
  const _SafTContactDialog();

  @override
  State<_SafTContactDialog> createState() => _SafTContactDialogState();
}

class _SafTContactDialogState extends State<_SafTContactDialog> {
  final _fields = FormControllers();

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.saftContactTitle),
      content: SingleChildScrollView(
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.saftContactIntro,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('saft-contact-first-name'),
                controller: _fields['first'],
                label: l10n.personalInfoFirstName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('saft-contact-last-name'),
                controller: _fields['last'],
                label: l10n.personalInfoLastName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
              ),
              const FormGap(),
              AppTextField(
                key: const ValueKey('saft-contact-phone'),
                controller: _fields['phone'],
                label: l10n.personalInfoPhone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('saft-contact-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('saft-contact-confirm'),
          onPressed: () => Navigator.of(context).pop(
            SafTContact(
              firstName: _fields.text('first'),
              lastName: _fields.text('last'),
              phone: _fields.text('phone'),
            ),
          ),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
