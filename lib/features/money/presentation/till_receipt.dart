// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- a sold basket as the receipt printer prints it: the words of the reader's language and the amounts in
// the business's currency, taken from what the server priced and numbered, never recomputed here. A copy repeats the
// receipt and says it is one; it never repeats the payment.
import '../../../core/format/decimal_input.dart';
import '../../../core/i18n/app_format.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/counter_till.dart';
import '../domain/escpos_receipt.dart';

/// What the receipt of a sale says. [givenMinor] is the cash the customer handed over, [changeMinor] what came back;
/// [copy] is the copy's number the server counted (#4476), null for the receipt as issued.
ReceiptPrint tillReceiptOf({
  required AppLocalizations l10n,
  required AppFormat fmt,
  required String business,
  required TillSold sold,
  required TillDraft draft,
  required List<TillLine> lines,
  required DateTime at,
  required int givenMinor,
  required int changeMinor,
  required int? copy,
}) {
  final money = fmt.moneyIn(sold.totals.currency);
  final separator = decimalSeparatorOf(fmt.locale);
  return ReceiptPrint(
    business: business,
    title: l10n.tillReceiptNumber(sold.number),
    issuedAt: fmt.dateTime(at),
    lines: [
      for (final (i, l) in lines.indexed)
        ReceiptPrintLine(
          label: l.name,
          amount: i < draft.lines.length ? money.formatMinor(draft.lines[i].grossMinor) : '',
          detail: l.quantity == '1' ? '' : '${l.quantity.replaceAll('.', separator)} ${l.unit}'.trim(),
        ),
    ],
    taxLabel: l10n.tillReceiptTax,
    tax: money.formatMinor(sold.totals.taxMinor),
    totalLabel: l10n.tillPrintTotal,
    total: money.formatMinor(sold.totals.grossMinor),
    tenders: [ReceiptPrintTender(label: l10n.tillReceiptCash, amount: money.formatMinor(givenMinor))],
    changeLabel: changeMinor > 0 ? l10n.tillReceiptChange : '',
    change: changeMinor > 0 ? money.formatMinor(changeMinor) : '',
    copyMark: copy == null ? '' : l10n.tillReceiptCopy('$copy'),
    footer: l10n.tillReceiptThanks,
  );
}
