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

AppFormSheet _mappingSheet(
  BuildContext context, {
  required List<String> columns,
  required String delimiter,
  required String currency,
  required ValueChanged<BankCsvMapping> onMapped,
}) {
  final l10n = context.l10n;
  final fields = FormControllers({'currency': currency});
  final chosen = <String, int?>{};
  var pattern = BankCsvDatePattern.isoDay;
  var decimalComma = delimiter == BankCsvDelimiters.semicolon;
  Set<BankCsvMappingProblem> problems() => bankCsvMappingProblems(
    account: fields.text('account'),
    currency: fields.text('currency'),
    dateColumn: chosen['date'],
    amountColumn: chosen['amount'],
  );
  return AppFormSheet(
    title: l10n.bankCsvTitle,
    submitLabel: l10n.bankFormatRead,
    submitKey: const ValueKey('bank-csv-read'),
    onDispose: fields.dispose,
    validate: () => {
      for (final p in problems())
        if (p == BankCsvMappingProblem.account ||
            p == BankCsvMappingProblem.currency)
          p.name: _problemText(l10n, p),
    },
    onSubmit: () async {
      // A column is not a typed field: what is still unchosen is said
      // above the buttons.
      final missing = problems();
      if (missing.isNotEmpty) return _problemText(l10n, missing.first);
      final debit = chosen['debit'];
      onMapped(
        BankCsvMapping(
          account: fields.text('account'),
          fixedCurrency: fields.text('currency').toUpperCase(),
          delimiter: delimiter,
          decimalComma: decimalComma,
          datePattern: pattern,
          bookingDate: chosen['date']!,
          valueDate: chosen['valueDate'],
          amount: debit == null ? chosen['amount'] : null,
          credit: debit == null ? null : chosen['amount'],
          debit: debit,
          counterpartyName: chosen['counterparty'],
          reference: chosen['reference'],
          remittance: chosen['remittance'],
          transactionId: chosen['transactionId'],
        ),
      );
      return null;
    },
    builder: (context, refresh) {
      Widget column(String key, String label, {bool optional = true}) =>
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: DropdownButtonFormField<int?>(
              key: ValueKey('bank-csv-$key'),
              initialValue: chosen[key],
              decoration: InputDecoration(labelText: label),
              items: [
                if (optional)
                  DropdownMenuItem<int?>(child: Text(l10n.bankCsvNone)),
                for (var i = 0; i < columns.length; i++)
                  DropdownMenuItem<int?>(value: i, child: Text(columns[i])),
              ],
              onChanged: (v) {
                chosen[key] = v;
                refresh();
              },
            ),
          );
      return [
        AppTextField(
          controller: fields['account'],
          fieldKey: 'account',
          label: l10n.bankCsvAccount,
          helper: l10n.bankCsvAccountHint,
        ),
        const FormGap(),
        AppTextField(
          controller: fields['currency'],
          fieldKey: 'currency',
          label: l10n.bankCsvCurrency,
          maxLength: 3,
        ),
        const FormGap(),
        DropdownButtonFormField<BankCsvDatePattern>(
          key: const ValueKey('bank-csv-date-pattern'),
          initialValue: pattern,
          decoration: InputDecoration(labelText: l10n.bankCsvDateFormat),
          items: [
            for (final p in BankCsvDatePattern.values)
              DropdownMenuItem(value: p, child: Text(bankCsvDateExample(p))),
          ],
          onChanged: (p) {
            pattern = p ?? pattern;
            refresh();
          },
        ),
        SwitchListTile(
          key: const ValueKey('bank-csv-decimal-comma'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.bankCsvDecimalComma),
          value: decimalComma,
          onChanged: (v) {
            decimalComma = v;
            refresh();
          },
        ),
        const FormGap(),
        column('date', l10n.bankCsvDate, optional: false),
        column('amount', l10n.bankCsvAmount, optional: false),
        column('debit', l10n.bankCsvDebit),
        column('valueDate', l10n.bankCsvValueDate),
        column('counterparty', l10n.bankCsvCounterparty),
        column('reference', l10n.bankCsvReference),
        column('remittance', l10n.bankCsvRemittance),
        column('transactionId', l10n.bankCsvTransactionId),
      ];
    },
  );
}

String _problemText(AppLocalizations l10n, BankCsvMappingProblem p) =>
    switch (p) {
      BankCsvMappingProblem.account => l10n.bankCsvNeedsAccount,
      BankCsvMappingProblem.currency => l10n.bankCsvNeedsCurrency,
      BankCsvMappingProblem.date => l10n.bankCsvNeedsDate,
      BankCsvMappingProblem.amount => l10n.bankCsvNeedsAmount,
    };
