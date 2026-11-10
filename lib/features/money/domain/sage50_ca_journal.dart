// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 -- the general journal of Sage 50 Accounting (Canada) as the text
// file its "Import Transactions" wizard reads, written from the posting
// engine's entries: one transaction per posting.
//
// spec: https://help-sage50.na.sage.com/en-ca/core/2017/Content/Import_Export/ImportingGeneralJournalEntries.htm
// (Transaction File Specifications), line order as documented/assumed:
//   * documented: the header line `mm-dd-yy,"source"[,"comment"]` (source up
//     to 20 characters, comment up to 75), `TAXH,<count>,<0 sales | 1
//     purchases>` and `TAXD,account,name,code,base,tax,other tax paid` (the
//     count must match), then one detail line `account,amount,"comment"` per
//     posting line (debit positive, credit negative; the amounts sum to zero);
//   * ASSUMED, not stated by the page: the TAXH/TAXD lines sit between the
//     header and the detail lines; a tax name and tax code are written as
//     quoted text equal to the tax scheme (GST, HST, QST, PST); the base and
//     tax amounts are positive where the tax moves in its natural direction
//     (output tax credited, input tax debited) and negative on a reversal;
//     "other tax paid" is 0.00.
// NOT verified against a live import: nothing has been imported into a Sage 50
// company. A transaction that touches a linked receivable or payable account is
// importable only from an accountant's copy (the page says so); the file
// carries every posting line as the engine booked it.
//
// The sales-invoice `.IMP` layout is a separate format whose public
// specification is missing (the knowledge base article 10032); this file does
// not write it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';

/// The longest source (cheque or invoice number) the format takes.
const int _sourceLength = 20;

/// The longest comment of a transaction header.
const int _commentLength = 75;

/// One tax of a tax line, as the TAXD line states it. Amounts are minor units
/// of the book's currency, positive.
class Sage50CaTaxPart {
  const Sage50CaTaxPart({
    required this.name,
    required this.code,
    required this.baseMinor,
    required this.taxMinor,
  });

  final String name;
  final String code;
  final int baseMinor;
  final int taxMinor;
}

/// The taxes a tax [line] of [posting] is made of, given its taxable base;
/// empty where the line is not split into taxes (no TAXD is written for it).
typedef Sage50CaTaxSplit =
    List<Sage50CaTaxPart> Function(
      Posting posting,
      PostingLine line,
      int baseMinor,
    );

/// What the journal of a set of postings is.
sealed class Sage50CaJournal {
  const Sage50CaJournal();
}

/// The file, lines separated by CRLF.
final class Sage50CaFile extends Sage50CaJournal {
  const Sage50CaFile(this.content);
  final String content;
}

/// Nothing was written: these facts cannot be expressed in the file.
final class Sage50CaRefused extends Sage50CaJournal {
  const Sage50CaRefused(this.sourceTooLong, this.unusableAccounts);

  /// Document numbers over [_sourceLength] characters.
  final List<String> sourceTooLong;

  /// Account codes that are empty or hold a comma, a quote or a line break.
  final List<String> unusableAccounts;
}

bool _usableAccount(String code) =>
    code.trim().isNotEmpty && !RegExp(r'[,"\r\n]').hasMatch(code);

bool _isTax(PostingLine l) =>
    l.role == BookRole.vatOutput || l.role == BookRole.vatInput;

/// The roles whose lines are the taxable base of a tax line of the same group.
const Set<BookRole> _baseRoles = {
  BookRole.revenue,
  BookRole.expenses,
  BookRole.fixedAssets,
  BookRole.stock,
  BookRole.prepayments,
  BookRole.deposits,
};

int _net(PostingLine l) => l.debit.minor - l.credit.minor;

String _quoted(String text, [int? max]) {
  final clean = text.replaceAll('"', "'").replaceAll(RegExp(r'[\r\n]+'), ' ');
  return '"${max != null && clean.length > max ? clean.substring(0, max) : clean}"';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime d) => '${_two(d.month)}-${_two(d.day)}-${_two(d.year % 100)}';

/// The tax header and detail lines of [p]: none where it holds tax of both
/// directions (one TAXH states one) or where no tax line is split.
List<String> _taxLines(Posting p, Sage50CaTaxSplit split) {
  final taxLines = [for (final l in p.lines) if (_isTax(l)) l];
  if (taxLines.isEmpty) return const [];
  final sales = taxLines.first.role == BookRole.vatOutput;
  if (taxLines.any((l) => (l.role == BookRole.vatOutput) != sales)) {
    return const [];
  }
  final details = <String>[];
  for (final line in taxLines) {
    var base = 0;
    for (final b in p.lines) {
      if (_baseRoles.contains(b.role) && b.qualifier == line.qualifier) {
        base += _net(b);
      }
    }
    // The natural direction: output tax is credited, input tax debited.
    final natural = sales ? _net(line) < 0 : _net(line) > 0;
    final sign = natural ? 1 : -1;
    for (final part in split(p, line, base.abs())) {
      final cur = line.debit.currency;
      details.add(
        'TAXD,${line.accountCode},${_quoted(part.name)},${_quoted(part.code)},'
        '${minorToText(sign * part.baseMinor, cur)},'
        '${minorToText(sign * part.taxMinor, cur)},${minorToText(0, cur)}',
      );
    }
  }
  if (details.isEmpty) return const [];
  return ['TAXH,${details.length},${sales ? 0 : 1}', ...details];
}

/// The journal of [postings]. [comment] words a transaction (at most
/// [_commentLength] characters are written); [split] names the taxes of
/// a tax line.
Sage50CaJournal buildSage50CaJournal(
  List<Posting> postings, {
  required String Function(Posting posting) comment,
  required Sage50CaTaxSplit split,
}) {
  final tooLong = <String>{
    for (final p in postings)
      if (p.documentNumber.length > _sourceLength) p.documentNumber,
  };
  final badAccounts = <String>{
    for (final p in postings)
      for (final l in p.lines)
        if (!_usableAccount(l.accountCode)) l.accountCode,
  };
  if (tooLong.isNotEmpty || badAccounts.isNotEmpty) {
    return Sage50CaRefused(tooLong.toList()..sort(), badAccounts.toList()..sort());
  }
  final lines = <String>[];
  for (final p in postings) {
    lines
      ..add(
        '${_date(p.date)},${_quoted(p.documentNumber)},'
        '${_quoted(comment(p), _commentLength)}',
      )
      ..addAll(_taxLines(p, split));
    for (final l in p.lines) {
      lines.add('${l.accountCode},${minorToText(_net(l), l.debit.currency)}');
    }
  }
  return Sage50CaFile(lines.isEmpty ? '' : '${lines.join('\r\n')}\r\n');
}

/// How far (in percentage points) the tax over the base may sit from a rate
/// of the tax reference before the line is left unsplit: a rounded cent on a
/// small base moves the ratio, a different rate moves it by more.
const double _rateTolerance = 0.1;

/// The taxes of a Canadian tax line, read from the tax reference. A rate
/// group names no single rate in Canada (13 % and 14.975 % share one), so the
/// rate is the one of the country's rate rows nearest to the line's tax over
/// its base, within [_rateTolerance]; the `rate_component` rows then
/// split it (GST + QST in Québec, one HST in Ontario). A line with no such
/// rate gets no part.
Sage50CaTaxSplit sage50CaTaxSplit(
  TaxReferenceSet reference, {
  required String country,
}) {
  return (posting, line, baseMinor) {
    if (baseMinor == 0) return const [];
    final day =
        '${posting.date.year}-${_two(posting.date.month)}-${_two(posting.date.day)}';
    final taxMinor = _net(line).abs();
    final actual = taxMinor * 100 / baseMinor;
    double? percent;
    for (final row in reference.ownRows(TaxDomain.rate, country, asOf: day)) {
      final value = row.value;
      if (value is! RateValue) continue;
      final off = (value.percent - actual).abs();
      if (off <= _rateTolerance &&
          (percent == null || off < (percent - actual).abs())) {
        percent = value.percent;
      }
    }
    if (percent == null) return const [];
    return [
      for (final c in vatComponentsOf(
        country,
        percent,
        baseMinor,
        taxMinor,
        asOf: day,
        reference: reference,
      ))
        Sage50CaTaxPart(
          name: c.scheme,
          code: c.scheme,
          baseMinor: c.baseCents,
          taxMinor: c.taxCents,
        ),
    ];
  };
}
