// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Swiss booking journal of a local book: the postings of the posting
// engine (`compute_postings`) on the issuer's KMU chart, one row per leg
// pair, with the MWST code of each taxed row and the Ziffer of the
// MWST-Abrechnung it lands on. Two layouts of the same rows:
//
//   * the journal (`ch_kmu`): `;` separated, UTF-8 with a byte order mark,
//     dates `dd.MM.yyyy`, CRLF; the QR reference of a receivable beside its
//     document number, the original amount of a converted line beside the
//     franc amount;
//   * Banana Accounting+'s transactions import (`banana_transactions`): the
//     same rows under Banana's column names (Date, Doc, Description,
//     AccountDebit, AccountCredit, Amount, VatCode), tab separated, ISO
//     dates, the amount gross: Banana splits the tax by the row's VatCode,
//     which must be a code of the file's VAT table.
//
// It serialises the postings and decides nothing: an entry the engine
// blocked never reaches it. A taxed row whose rate group has no MWST code
// in the tax reference stops the file and names the group.
//
// Pure Dart.
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import 'accounting_amount.dart';
import 'book_chart.dart';
import 'posting.dart';
import 'vat_form_catalogue/ch.dart';
import 'vat_form_terms.dart';
import 'vat_forms.dart';

/// The two files the Swiss journal is written as.
enum SwissJournalLayout { kmu, banana }

/// One row of the journal: one debit and one credit account (one of them
/// empty in a composite entry), the gross amount and how its tax is coded.
class SwissJournalRow {
  const SwissJournalRow({
    required this.date,
    required this.document,
    required this.text,
    required this.debit,
    required this.credit,
    required this.amount,
    this.reference = '',
    this.vatCode = '',
    this.vat,
    this.vatAccount = '',
    this.ziffer = '',
    this.original,
    this.party = '',
  });

  final DateTime date;
  final String document;

  /// The QR reference (QRR or SCOR) of a receivable's invoice.
  final String reference;
  final String text;
  final String debit;
  final String credit;

  /// In the book's currency, gross of [vat].
  final AccountingAmount amount;
  final String vatCode;
  final AccountingAmount? vat;
  final String vatAccount;
  final String ziffer;

  /// The amount in the document's own currency, when it was converted.
  final AccountingAmount? original;
  final String party;
}

/// The rows of a year's postings, or the tax keys (`tax:<group>`,
/// `input:<group>`, `asset:<group>`) that have no MWST code.
typedef SwissJournal = ({
  List<SwissJournalRow> rows,
  List<String> missingCodes,
});

/// The reference key of the MWST code of [leg]'s tax: output tax under
/// `tax:<group>`, input tax under `input:<group>`, and the input tax of an
/// asset (Ziffer 405) under `asset:<group>`.
String _codeKey(_Leg leg, PostingLine tax) {
  final kind = tax.role != BookRole.vatInput
      ? 'tax'
      : leg.line.role == BookRole.fixedAssets
      ? 'asset'
      : 'input';
  return '$kind:${_groupOf(leg) ?? ''}';
}

/// The rate group of [leg]: its tax line's, else its base's (output tax
/// waiting on `vat_pending` names no group; the revenue it is booked with
/// does).
String? _groupOf(_Leg leg) => leg.tax?.qualifier ?? leg.line.qualifier;

bool _isTax(PostingLine l) =>
    l.role == BookRole.vatOutput || l.role == BookRole.vatInput;

/// Whether [l] is the tax of [base], booked with it on the same side: its
/// output or input tax, or (a book on collected consideration) its output
/// tax waiting on `vat_pending` for its tax point, when [base] names the
/// rate group that tax belongs to.
bool _taxOf(PostingLine base, PostingLine l) =>
    !_isTax(base) &&
    base.role != BookRole.vatPending &&
    _onDebit(base) == _onDebit(l) &&
    (_isTax(l) || (l.role == BookRole.vatPending && base.qualifier != null));

bool _onDebit(PostingLine l) => l.debit.minor != 0;

AccountingAmount _side(PostingLine l) => _onDebit(l) ? l.debit : l.credit;

/// A line and the tax line booked with it on the same side.
typedef _Leg = ({PostingLine line, PostingLine? tax});

/// The legs of [lines]: a tax line that follows its base on the same side
/// is folded into it, as the posting rules write them (revenue then its
/// output tax, due or pending; an expense then its input tax). The release
/// of pending tax (`vat_pending` to `vat_output`) stays two legs.
List<_Leg> _legs(List<PostingLine> lines) {
  final out = <_Leg>[];
  for (final l in lines) {
    final last = out.lastOrNull;
    if (last != null && last.tax == null && _taxOf(last.line, l)) {
      out[out.length - 1] = (line: last.line, tax: l);
    } else {
      out.add((line: l, tax: null));
    }
  }
  return out;
}

AccountingAmount _gross(_Leg leg) => switch (leg.tax) {
  final t? => _side(leg.line) + _side(t),
  null => _side(leg.line),
};

AccountingAmount? _original(_Leg leg) =>
    switch ((leg.line.original, leg.tax?.original)) {
      (final a?, final b?) => a + b,
      (final a?, null) => a,
      _ => null,
    };

bool _selects(VatBoxSpec box, bool Function(VatLineSelector s) test) => [
  ...box.base,
  ...box.tax,
].any((t) => t.selector != null && test(t.selector!));

/// The first box of the form whose line terms [test] accepts.
String _boxWhere(bool Function(VatBoxSpec box) test) =>
    chMwstSpec.boxes.where(test).firstOrNull?.code ?? '';

/// The Ziffer of the MWST-Abrechnung (the effective method's form,
/// `chMwstSpec`) a leg lands on, read from the form and the tax reference:
/// a taxed sale on the rate line whose `form_box` row names its group, an
/// untaxed sale on the deduction of its rate's category (220, 221, 230),
/// input tax on 400 or, for an asset, 405. '' where the form has no line.
String _zifferOf(_Leg leg, TaxReferenceSet onDay) {
  final tax = leg.tax;
  if (tax != null && tax.role == BookRole.vatInput) {
    final kind = leg.line.role == BookRole.fixedAssets ? vatAsset : vatTaxable;
    return _boxWhere(
      (box) => _selects(
        box,
        (s) => s.input && (s.categories?.containsAll(kind) ?? false),
      ),
    );
  }
  final group = _groupOf(leg);
  if (group == null) return '';
  // A released output tax lands on its rate line on its tax point, like the
  // taxed sale it was waiting for.
  if (tax != null || leg.line.role == BookRole.vatOutput) {
    // The rate line of a sale: not the opted part of it (205), not the
    // acquisition tax on a purchase (383).
    return _boxWhere((box) {
      final row = box.formBox == null
          ? null
          : onDay.lookup(TaxDomain.formBox, chMwstSpec.country, box.formBox!);
      return ((row?.value as FormBoxValue?)?.groups.contains(group) ?? false) &&
          _selects(
            box,
            (s) => !s.input && !s.opted && (s.categories?.containsAll(vatTaxable) ?? false),
          );
    });
  }
  if (leg.line.role != BookRole.revenue) return '';
  final category = [
    for (final r in onDay.where(TaxDomain.rate, country: chMwstSpec.country))
      if (r.value case RateValue(group: final g, :final category)
          when g == group)
        category,
  ].firstOrNull;
  if (category == null) return '';
  return _boxWhere(
    (box) =>
        box.formBox == null &&
        _selects(
          box,
          (s) => !s.input && (s.categories?.contains(category) ?? false),
        ),
  );
}

/// The Swiss journal of [postings] in their order. The MWST code of each
/// taxed row is the `ch_kmu/<tax key>` row of [reference] in force on the
/// row's day; [paymentReferences] holds the QR reference of each invoice
/// by document id, [parties] the documents' customers and suppliers;
/// [kindText] names each entry's event in the Text column.
SwissJournal swissJournalOf(
  List<Posting> postings, {
  required TaxReferenceSet reference,
  required String Function(PostingKind kind) kindText,
  Map<String, String> paymentReferences = const {},
  Map<String, PostingParty> parties = const {},
}) {
  final rows = <SwissJournalRow>[];
  final missing = <String>{};
  for (final p in postings) {
    final onDay = reference.on(isoDay(p.date));
    final receivable = p.lines.any((l) => l.role == BookRole.customers);
    for (final (:leg, :debit, :credit) in _pairs(_legs(p.lines))) {
      final code = _codeOf(leg, onDay);
      if (code.missing case final key?) missing.add(key);
      rows.add(
        SwissJournalRow(
          date: p.date,
          document: p.documentNumber,
          reference: receivable ? paymentReferences[p.documentId] ?? '' : '',
          text: '${p.documentNumber} ${kindText(p.kind)}',
          debit: debit,
          credit: credit,
          amount: _gross(leg),
          vatCode: code.code,
          vat: leg.tax == null ? null : _side(leg.tax!),
          vatAccount: leg.tax?.accountCode ?? '',
          ziffer: _zifferOf(leg, onDay),
          original: _original(leg),
          party: parties[p.documentId]?.number ?? '',
        ),
      );
    }
  }
  return (rows: rows, missingCodes: [...missing]..sort());
}

/// The MWST code of [leg]'s tax on its day ('' for an untaxed leg), or the
/// tax key that has none.
({String code, String? missing}) _codeOf(_Leg leg, TaxReferenceSet onDay) {
  final tax = leg.tax;
  if (tax == null) return (code: '', missing: null);
  final key = _codeKey(leg, tax);
  final value = onDay
      .lookup(TaxDomain.accountMap, chMwstSpec.country, 'ch_kmu/$key')
      ?.value;
  final code = (value as AccountMapValue?)?.taxCode ?? '';
  return (code: code, missing: code.isEmpty ? key : null);
}

/// The rows of one entry's [legs]: each leg with the debit and credit
/// account its row names.
List<({_Leg leg, String debit, String credit})> _pairs(List<_Leg> legs) {
  final debits = [
    for (final l in legs)
      if (_onDebit(l.line)) l,
  ];
  final credits = [
    for (final l in legs)
      if (!_onDebit(l.line)) l,
  ];
  if (debits.length == 1 && credits.length == 1) {
    // One row; it carries the tax of whichever side has it, and a release
    // of pending tax the rate group of the output tax it credits. The
    // release carries no MWST code: the sale was coded once, on its own row,
    // and a code here would tax the tax again.
    final (d, c) = (debits.single, credits.single);
    return [
      (
        leg: c.tax != null || c.line.qualifier != null ? c : d,
        debit: d.line.accountCode,
        credit: c.line.accountCode,
      ),
    ];
  }
  if (credits.length == 1 && credits.single.tax == null) {
    // One untaxed credit (the customer of a write-off, the supplier of a
    // bill): each debit leg against it.
    final c = credits.single.line.accountCode;
    return [
      for (final d in debits) (leg: d, debit: d.line.accountCode, credit: c),
    ];
  }
  if (debits.length == 1 && debits.single.tax == null) {
    // One untaxed debit (the customer of an invoice): each credit leg.
    final d = debits.single.line.accountCode;
    return [
      for (final c in credits) (leg: c, debit: d, credit: c.line.accountCode),
    ];
  }
  // A composite entry: one account per row, the entry held together by its
  // document, as Banana reads a split booking.
  return [
    for (final l in legs)
      (
        leg: l,
        debit: _onDebit(l.line) ? l.line.accountCode : '',
        credit: _onDebit(l.line) ? '' : l.line.accountCode,
      ),
  ];
}

String _dotted(DateTime on) =>
    '${twoDigits(on.day)}.${twoDigits(on.month)}.${on.year}';

const _kmuHeader = [
  'Datum',
  'Beleg',
  'Referenz',
  'Text',
  'Soll',
  'Haben',
  'Betrag',
  'Waehrung',
  'MWST-Code',
  'MWST-Betrag',
  'MWST-Konto',
  'Ziffer',
  'Fremdbetrag',
  'Fremdwaehrung',
  'Partner',
];

/// Banana Accounting+'s column names of the Transactions table, the header
/// its import of transactions maps by name.
const _bananaHeader = [
  'Date',
  'Doc',
  'Description',
  'AccountDebit',
  'AccountCredit',
  'Amount',
  'VatCode',
];

final _tabOrBreak = RegExp(r'[\t\r\n]');

String _kmuLine(SwissJournalRow r) => [
  _dotted(r.date),
  csvCell(r.document),
  csvCell(r.reference),
  csvCell(r.text),
  r.debit,
  r.credit,
  r.amount.toDecimalString(),
  r.amount.currency,
  r.vatCode,
  r.vat?.toDecimalString() ?? '',
  r.vatAccount,
  r.ziffer,
  r.original?.toDecimalString() ?? '',
  r.original?.currency ?? '',
  csvCell(r.party),
].join(';');

String _bananaLine(SwissJournalRow r) => [
  isoDay(r.date),
  r.document.replaceAll(_tabOrBreak, ' '),
  r.text.replaceAll(_tabOrBreak, ' '),
  r.debit,
  r.credit,
  r.amount.toDecimalString(),
  r.vatCode,
].join('\t');

/// [rows] written in [layout].
String swissJournalFile(
  List<SwissJournalRow> rows,
  SwissJournalLayout layout,
) => switch (layout) {
  SwissJournalLayout.kmu =>
    '\u{FEFF}${[_kmuHeader.join(';'), ...rows.map(_kmuLine)].join('\r\n')}\r\n',
  SwissJournalLayout.banana =>
    '${[_bananaHeader.join('\t'), ...rows.map(_bananaLine)].join('\r\n')}\r\n',
};
