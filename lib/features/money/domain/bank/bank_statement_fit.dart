// SPDX-License-Identifier: AGPL-3.0-or-later
// Normalization shared by import and retained-source verification.
import 'bank_statement.dart';

/// [s] as the store keeps it: an account or a bank id that does not fit
/// refuses the file, by name; a name or a text is cut to its column; an
/// end-to-end id or an IBAN that does not fit is left out.
BankStatement fitBankStatement(BankStatement s) {
  BankFileException tooLong(int? line, String what) =>
      BankFileException(BankFileProblem.tooLong, line: line, detail: what);
  if (s.account.trim().length > BankColumnWidths.account) {
    throw tooLong(null, 'account');
  }
  return BankStatement(
    format: s.format,
    account: s.account,
    currency: s.currency,
    statementId: _cut(s.statementId, BankColumnWidths.statementRef),
    openingCents: s.openingCents,
    closingCents: s.closingCents,
    lines: [
      for (final l in s.lines)
        if (l.transactionId.length > BankColumnWidths.transactionId)
          throw tooLong(l.position, 'transaction id')
        else
          BankLine(
            position: l.position,
            bookingDate: l.bookingDate,
            valueDate: l.valueDate,
            amountCents: l.amountCents,
            currency: l.currency,
            transactionId: l.transactionId,
            counterpartyName: _cut(
              l.counterpartyName,
              BankColumnWidths.counterpartyName,
            ),
            counterpartyIban: BankColumnWidths.iban.hasMatch(l.counterpartyIban)
                ? l.counterpartyIban
                : '',
            reference: l.reference,
            endToEndId: l.endToEndId.length > BankColumnWidths.endToEndId
                ? ''
                : l.endToEndId,
            remittance: _cut(l.remittance, BankColumnWidths.remittance),
          ),
    ],
  );
}

String _cut(String s, int width) =>
    s.length <= width ? s : s.substring(0, width);
