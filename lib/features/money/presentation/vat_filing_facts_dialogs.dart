// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a Spanish or an Italian filing file states that the workspace's
// settings do not hold, asked when the file is saved and not stored: the
// registers a Spanish space is in, the declarant who signs an Italian
// return for a company.
import 'package:flutter/material.dart';

import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/vat_filing_files.dart';

/// Asks the registers the Modelo 303 file declares; null when cancelled.
Future<VatFilingFacts?> askSpanishFilingFacts(
  BuildContext context,
  AppLocalizations l10n,
) => showDialog<VatFilingFacts>(
  context: context,
  builder: (context) => _SpanishFactsDialog(l10n: l10n),
);

/// Asks the declarant the LIPE names; null when cancelled.
Future<VatFilingFacts?> askItalianDeclarant(
  BuildContext context,
  AppLocalizations l10n,
) => showDialog<VatFilingFacts>(
  context: context,
  builder: (context) => _ItalianDeclarantDialog(l10n: l10n),
);

class _SpanishFactsDialog extends StatefulWidget {
  const _SpanishFactsDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_SpanishFactsDialog> createState() => _SpanishFactsDialogState();
}

class _SpanishFactsDialogState extends State<_SpanishFactsDialog> {
  var _facts = const VatFilingFacts();

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    Widget toggle(
      String label, {
      required Key key,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
    return AlertDialog(
      title: Text(l10n.vatDeclAeat303),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.vatDeclFilingEsIntro),
            const FormGap(),
            toggle(
              l10n.vatDeclFilingEsMonthlyRefund,
              key: const ValueKey('vat-filing-es-redeme'),
              value: _facts.monthlyRefund,
              onChanged: (v) => setState(
                () => _facts = VatFilingFacts(
                  monthlyRefund: v,
                  immediateSupply: _facts.immediateSupply,
                  cashCriterionRecipient: _facts.cashCriterionRecipient,
                ),
              ),
            ),
            toggle(
              l10n.vatDeclFilingEsSii,
              key: const ValueKey('vat-filing-es-sii'),
              value: _facts.immediateSupply,
              onChanged: (v) => setState(
                () => _facts = VatFilingFacts(
                  monthlyRefund: _facts.monthlyRefund,
                  immediateSupply: v,
                  cashCriterionRecipient: _facts.cashCriterionRecipient,
                ),
              ),
            ),
            toggle(
              l10n.vatDeclFilingEsCashRecipient,
              key: const ValueKey('vat-filing-es-cash-recipient'),
              value: _facts.cashCriterionRecipient,
              onChanged: (v) => setState(
                () => _facts = VatFilingFacts(
                  monthlyRefund: _facts.monthlyRefund,
                  immediateSupply: _facts.immediateSupply,
                  cashCriterionRecipient: v,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-filing-es-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-filing-es-ok'),
          onPressed: () => Navigator.of(context).pop(_facts),
          child: Text(l10n.vatDeclAeat303),
        ),
      ],
    );
  }
}

class _ItalianDeclarantDialog extends StatefulWidget {
  const _ItalianDeclarantDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_ItalianDeclarantDialog> createState() =>
      _ItalianDeclarantDialogState();
}

class _ItalianDeclarantDialogState extends State<_ItalianDeclarantDialog> {
  final _fields = FormControllers({'fiscalCode': '', 'role': ''});

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.vatDeclLipeXml),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.vatDeclFilingItIntro),
            const FormGap(),
            AppTextField(
              key: const ValueKey('vat-filing-it-cf'),
              controller: _fields['fiscalCode'],
              fieldKey: 'fiscalCode',
              autofocus: true,
              label: l10n.vatDeclFilingItDeclarantCf,
            ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('vat-filing-it-role'),
              controller: _fields['role'],
              fieldKey: 'role',
              keyboardType: TextInputType.number,
              label: l10n.vatDeclFilingItDeclarantRole,
              helper: l10n.vatDeclFilingItDeclarantRoleHelp,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-filing-it-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-filing-it-ok'),
          onPressed: () => Navigator.of(context).pop(
            VatFilingFacts(
              declarantFiscalCode: _fields.text('fiscalCode'),
              declarantRole: _fields.text('role'),
            ),
          ),
          child: Text(l10n.vatDeclLipeXml),
        ),
      ],
    );
  }
}
