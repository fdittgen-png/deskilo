// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the contact person a SAF-T Financial file names in its header
// (Company/Contact, mandatory in every profile; Luxembourg also requires a
// telephone). Asked at export, like DATEV's adviser numbers: it is a fact of
// this file, written into it and nowhere else.
//
// #2379 — Austria's header also states how the profit is determined
// (TaxAccountingBasis: one of the provisions of the EStG 1988) and the
// industry code (TaxEntity, Branchenkennzahl): facts of the company the app
// does not hold, asked here for that file.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/saf_t_financial.dart';

/// The provisions of the Austrian EStG 1988 a book's profit follows.
const _austrianProfitBases = ['§ 4 Abs. 1 EStG', '§ 4 Abs. 3 EStG', '§ 5 EStG'];

/// What the person states for the file: the contact, and for Austria the
/// profit basis and the industry code (empty elsewhere).
typedef SafTHeaderAnswers = ({SafTContact contact, String profitBasis, String industryCode});

/// The answers, or null when the person backed out. [austria] also asks
/// Austria's two header facts.
Future<SafTHeaderAnswers?> showSafTContactDialog(BuildContext context, {bool austria = false}) =>
    showDialog<SafTHeaderAnswers>(
      context: context,
      builder: (context) => _SafTContactDialog(austria: austria),
    );

class _SafTContactDialog extends StatefulWidget {
  const _SafTContactDialog({required this.austria});

  final bool austria;

  @override
  State<_SafTContactDialog> createState() => _SafTContactDialogState();
}

class _SafTContactDialogState extends State<_SafTContactDialog> {
  final _fields = FormControllers();
  String _profitBasis = '';

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
              if (widget.austria) ...[
                const FormGap(),
                DropdownButtonFormField<String>(
                  key: const ValueKey('saft-profit-basis'),
                  decoration: InputDecoration(
                    labelText: l10n.saftProfitBasisLabel,
                    helperText: l10n.saftProfitBasisHelper,
                    helperMaxLines: 3,
                  ),
                  items: [
                    for (final b in _austrianProfitBases)
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (b) => setState(() => _profitBasis = b ?? ''),
                ),
                const FormGap(),
                AppTextField(
                  key: const ValueKey('saft-industry-code'),
                  controller: _fields['industry'],
                  label: l10n.saftIndustryCodeLabel,
                  helper: l10n.saftIndustryCodeHelper,
                  keyboardType: TextInputType.number,
                ),
              ],
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
          onPressed: () => Navigator.of(context).pop((
            contact: SafTContact(
              firstName: _fields.text('first'),
              lastName: _fields.text('last'),
              phone: _fields.text('phone'),
            ),
            profitBasis: _profitBasis,
            industryCode: _fields.text('industry'),
          )),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
