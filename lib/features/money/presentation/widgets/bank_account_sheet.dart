// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4496 -- a bank account of the business, made or changed: its name, its IBAN, its other identifiers and the names it
// is also known by (one per line), its currency and the ledger account it books to (a posting asset account of the
// business's book, when it keeps one). The server decides; its refusal is said under the sheet's buttons.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/currency_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/bank/bank_account.dart';
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
  required Future<({String id, int attached})> Function(BankAccount account) save,
}) async {
  final l10n = context.l10n;
  final fields = FormControllers({
    'name': account?.name ?? '',
    'iban': account?.iban ?? '',
    'identifiers': (account?.identifiers ?? const []).join('\n'),
    'aliases': (account?.aliases ?? const []).join('\n'),
    'currency': account?.currency ?? currency,
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
      validate: () => {
        if (fields.text('name').trim().isEmpty) 'name': l10n.bankAccountRefusedName,
      },
      onSubmit: () async {
        try {
          final saved = await save(BankAccount(
            id: account?.id ?? '',
            name: fields.text('name').trim(),
            iban: fields.text('iban'),
            identifiers: _lines(fields.text('identifiers')),
            aliases: _lines(fields.text('aliases')),
            currency: fields.text('currency').trim().toUpperCase(),
            bookAccountId: ledgerId,
          ));
          attached = saved.attached;
          return null;
        } on BankAccountRefused catch (e, st) {
          TraceLogger.instance.log(TraceLevel.info, 'money', 'a bank account refused', error: e, stackTrace: st);
          return bankAccountRefusalText(l10n, e);
        }
      },
      builder: (context, refresh) => [
        AppTextField(
          key: const ValueKey('bank-account-name'),
          controller: fields['name'],
          fieldKey: 'name',
          label: l10n.bankAccountName,
          maxLength: 64,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('bank-account-iban'),
          controller: fields['iban'],
          fieldKey: 'iban',
          label: l10n.bankAccountIban,
          helper: l10n.bankAccountIbanHint,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('bank-account-identifiers'),
          controller: fields['identifiers'],
          fieldKey: 'identifiers',
          label: l10n.bankAccountIdentifiers,
          helper: l10n.bankAccountIdentifiersHint,
          maxLines: 3,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('bank-account-aliases'),
          controller: fields['aliases'],
          fieldKey: 'aliases',
          label: l10n.bankAccountAliases,
          helper: l10n.bankAccountAliasesHint,
          maxLines: 3,
        ),
        const FormGap(),
        CurrencyField(
          textKey: const ValueKey('bank-account-currency'),
          controller: fields['currency'],
          fieldKey: 'currency',
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
