// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — how a spreadsheet export of the bank is read: the account it is
// about (a CSV rarely names it), its currency, how it writes days and
// amounts, and which column holds what, chosen among the file's own
// column names.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/bank_import_commands.dart';
import '../../domain/bank/bank_statement.dart';
import '../../domain/bank/csv_statement.dart';
import '../bank_labels.dart';

/// The mapping the person chose for the CSV [bytes]; null when they left.
Future<BankCsvMapping?> showBankCsvMapping(
  BuildContext context,
  List<int> bytes, {
  required String currency,
}) async {
  final firstLine = String.fromCharCodes(bytes.takeWhile((b) => b != 10));
  final delimiter = guessCsvDelimiter(firstLine);
  final columns = csvHeaderOf(bytes, delimiter);
  BankCsvMapping? chosen;
  await showAppFormSheet(
    context,
    _mappingSheet(
      context,
      columns: columns,
      delimiter: delimiter,
      currency: currency,
      onMapped: (m) => chosen = m,
    ),
  );
  return chosen;
}

/// Every column but the date, the amount and the currency, for the check
/// that no column is chosen twice.
const List<String> _otherColumns = [
  'debit',
  'valueDate',
  'counterparty',
  'counterpartyIban',
  'reference',
  'remittance',
  'transactionId',
];

/// What the person chose so far: the typed fields and the column choices.
class _CsvDraft {
  _CsvDraft({
    required this.columns,
    required this.delimiter,
    required String currency,
  }) : fields = FormControllers({'currency': currency}),
       decimalComma = delimiter == BankCsvDelimiters.semicolon;

  final List<String> columns;
  final String delimiter;
  final FormControllers fields;
  final chosen = <String, int?>{};
  BankCsvDatePattern pattern = BankCsvDatePattern.isoDay;
  bool decimalComma;
  bool header = true;

  Set<BankCsvMappingProblem> problems() => bankCsvMappingProblems(
    account: fields.text('account'),
    currency: fields.text('currency'),
    dateColumn: chosen['date'],
    amountColumn: chosen['amount'],
    currencyColumn: chosen['currency'],
    otherColumns: [for (final k in _otherColumns) chosen[k]],
  );

  BankCsvMapping mapping() {
    final debit = chosen['debit'];
    return BankCsvMapping(
      account: fields.text('account'),
      fixedCurrency: fields.text('currency').toUpperCase(),
      currency: chosen['currency'],
      delimiter: delimiter,
      decimalComma: decimalComma,
      header: header,
      datePattern: pattern,
      bookingDate: chosen['date']!,
      valueDate: chosen['valueDate'],
      amount: debit == null ? chosen['amount'] : null,
      credit: debit == null ? null : chosen['amount'],
      debit: debit,
      counterpartyName: chosen['counterparty'],
      counterpartyIban: chosen['counterpartyIban'],
      reference: chosen['reference'],
      remittance: chosen['remittance'],
      transactionId: chosen['transactionId'],
    );
  }
}

AppFormSheet _mappingSheet(
  BuildContext context, {
  required List<String> columns,
  required String delimiter,
  required String currency,
  required ValueChanged<BankCsvMapping> onMapped,
}) {
  final l10n = context.l10n;
  final draft = _CsvDraft(
    columns: columns,
    delimiter: delimiter,
    currency: currency,
  );
  return AppFormSheet(
    title: l10n.bankCsvTitle,
    submitLabel: l10n.bankFormatRead,
    submitKey: const ValueKey('bank-csv-read'),
    onDispose: draft.fields.dispose,
    validate: () => {
      for (final p in draft.problems())
        if (p == BankCsvMappingProblem.account ||
            p == BankCsvMappingProblem.currency)
          p.name: _problemText(l10n, p),
    },
    onSubmit: () async {
      // A column is not a typed field: what is still unchosen is said
      // above the buttons.
      final missing = draft.problems();
      if (missing.isNotEmpty) return _problemText(l10n, missing.first);
      onMapped(draft.mapping());
      return null;
    },
    builder: (context, refresh) => [
      ..._typedFields(context, draft, refresh),
      ..._columnFields(context, draft, refresh),
    ],
  );
}

List<Widget> _typedFields(
  BuildContext context,
  _CsvDraft draft,
  VoidCallback refresh,
) {
  final l10n = context.l10n;
  return [
    AppTextField(
      key: const ValueKey('bank-csv-account'),
      controller: draft.fields['account'],
      fieldKey: 'account',
      label: l10n.bankCsvAccount,
      helper: l10n.bankCsvAccountHint,
      maxLength: BankColumnWidths.account,
    ),
    const FormGap(),
    AppTextField(
      key: const ValueKey('bank-csv-currency'),
      controller: draft.fields['currency'],
      fieldKey: 'currency',
      label: l10n.bankCsvCurrency,
      maxLength: 3,
    ),
    const FormGap(),
    DropdownButtonFormField<BankCsvDatePattern>(
      key: const ValueKey('bank-csv-date-pattern'),
      initialValue: draft.pattern,
      decoration: InputDecoration(labelText: l10n.bankCsvDateFormat),
      items: [
        for (final p in BankCsvDatePattern.values)
          DropdownMenuItem(value: p, child: Text(bankCsvDateExample(p))),
      ],
      onChanged: (p) {
        draft.pattern = p ?? draft.pattern;
        refresh();
      },
    ),
    SwitchListTile(
      key: const ValueKey('bank-csv-header'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.bankCsvHeader),
      value: draft.header,
      onChanged: (v) {
        draft.header = v;
        refresh();
      },
    ),
    SwitchListTile(
      key: const ValueKey('bank-csv-decimal-comma'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.bankCsvDecimalComma),
      value: draft.decimalComma,
      onChanged: (v) {
        draft.decimalComma = v;
        refresh();
      },
    ),
    const FormGap(),
  ];
}

List<Widget> _columnFields(
  BuildContext context,
  _CsvDraft draft,
  VoidCallback refresh,
) {
  final l10n = context.l10n;
  Widget column(String key, String label, {bool optional = true}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: DropdownButtonFormField<int?>(
      key: ValueKey('bank-csv-$key'),
      initialValue: draft.chosen[key],
      decoration: InputDecoration(labelText: label),
      items: [
        if (optional) DropdownMenuItem<int?>(child: Text(l10n.bankCsvNone)),
        for (var i = 0; i < draft.columns.length; i++)
          DropdownMenuItem<int?>(
            value: i,
            child: Text(
              draft.header
                  ? draft.columns[i]
                  : l10n.bankCsvColumn(i + 1, draft.columns[i]),
            ),
          ),
      ],
      onChanged: (v) {
        draft.chosen[key] = v;
        refresh();
      },
    ),
  );
  return [
    column('date', l10n.bankCsvDate, optional: false),
    column('amount', l10n.bankCsvAmount, optional: false),
    column('debit', l10n.bankCsvDebit),
    column('valueDate', l10n.bankCsvValueDate),
    column('currency', l10n.bankCsvCurrencyColumn),
    column('counterparty', l10n.bankCsvCounterparty),
    column('counterpartyIban', l10n.bankCsvCounterpartyIban),
    column('reference', l10n.bankCsvReference),
    column('remittance', l10n.bankCsvRemittance),
    column('transactionId', l10n.bankCsvTransactionId),
  ];
}

String _problemText(AppLocalizations l10n, BankCsvMappingProblem p) =>
    switch (p) {
      BankCsvMappingProblem.account => l10n.bankCsvNeedsAccount(
    BankColumnWidths.account,
  ),
      BankCsvMappingProblem.currency => l10n.bankCsvNeedsCurrency,
      BankCsvMappingProblem.date => l10n.bankCsvNeedsDate,
      BankCsvMappingProblem.amount => l10n.bankCsvNeedsAmount,
      BankCsvMappingProblem.duplicateColumn => l10n.bankCsvDuplicateColumn,
    };
