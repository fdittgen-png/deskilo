// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- a bank account of the business, made or changed: its name, its IBAN, its other identifiers and the names it
// is also known by (one per line), its currency and the ledger account it books to (a posting asset account of the
// business's book, when it keeps one). The server decides; its refusal is said under the sheet's buttons.
import 'package:flutter/material.dart';

import '../../../../core/bank/bank_account.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/currency_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/bank/bank_statement.dart' show BankColumnWidths;
import '../../domain/book_chart.dart';
import '../bank_account_words.dart';

List<String> _lines(String text) => [
  for (final l in text.split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];

/// Opens the editor of [account] (null: a new one, in [currency]); [save] writes it and answers how many statements it
/// took on. Answers that number once saved, null when the person left.
Future<int?> showBankAccountSheet(
  BuildContext context, {
  required BankAccount? account,
  required String currency,
  required List<BookAccount> ledger,
  required Future<int> Function(BankAccount account) save,
}) async {
  final l10n = context.l10n;
  final fields = FormControllers({
    'accountName': account?.name ?? '',
    'accountIban': account?.iban ?? '',
    'accountIdentifiers': (account?.identifiers ?? const []).join('\n'),
    'accountAliases': (account?.aliases ?? const []).join('\n'),
    'accountCurrency': account?.currency ?? currency,
  });
  String? ledgerId = account?.bookAccountId;
  int? attached;
  await showAppFormSheet(
    context,
    AppFormSheet(
      title: account == null ? l10n.bankAccountAdd : l10n.bankAccountEdit,
      submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
      submitKey: const ValueKey('bank-account-save'),
      onDispose: fields.dispose,
      validate: () => {if (fields.text('accountName').trim().isEmpty) 'accountName': l10n.bankAccountRefusedName},
      onSubmit: () async {
        try {
          attached = await save(
            BankAccount(
              id: account?.id ?? '',
              name: fields.text('accountName').trim(),
              iban: fields.text('accountIban'),
              identifiers: _lines(fields.text('accountIdentifiers')),
              aliases: _lines(fields.text('accountAliases')),
              currency: fields.text('accountCurrency').trim().toUpperCase(),
              bookAccountId: ledgerId,
            ),
          );
          return null;
        } on BankAccountRefused catch (e, st) {
          TraceLogger.instance.log(TraceLevel.info, 'money', 'a bank account refused', error: e, stackTrace: st);
          return bankAccountRefusalText(l10n, e);
        }
      },
      builder: (context, refresh) => [
        AppTextField(
          key: const ValueKey('bank-account-name'),
          controller: fields['accountName'],
          fieldKey: 'accountName',
          label: l10n.bankAccountName,
          maxLength: BankColumnWidths.account,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('bank-account-iban'),
          controller: fields['accountIban'],
          fieldKey: 'accountIban',
          label: l10n.paymentInstructionsIbanTitle,
          helper: l10n.bankAccountIbanHint,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('bank-account-identifiers'),
          controller: fields['accountIdentifiers'],
          fieldKey: 'accountIdentifiers',
          label: l10n.bankAccountIdentifiers,
          helper: l10n.bankAccountIdentifiersHint,
          maxLines: 3,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('bank-account-aliases'),
          controller: fields['accountAliases'],
          fieldKey: 'accountAliases',
          label: l10n.bankAccountAliases,
          helper: l10n.bankAccountAliasesHint,
          maxLines: 3,
        ),
        const FormGap(),
        CurrencyField(
          textKey: const ValueKey('bank-account-currency'),
          controller: fields['accountCurrency'],
          fieldKey: 'accountCurrency',
          label: l10n.bankAccountCurrency,
        ),
        if (ledger.isNotEmpty) ...[
          const FormGap(),
          DropdownButtonFormField<String?>(
            key: const ValueKey('bank-account-ledger'),
            initialValue: ledgerId,
            decoration: InputDecoration(labelText: l10n.bankAccountLedger),
            items: [
              DropdownMenuItem<String?>(child: Text(l10n.bankAccountLedgerNone)),
              for (final a in ledger) DropdownMenuItem<String?>(value: a.id, child: Text('${a.code} ${a.name}')),
            ],
            onChanged: (id) => ledgerId = id,
          ),
        ],
      ],
    ),
  );
  return attached;
}
