// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — how a document WOULD post. A read-only projection of an
// invoice or a payment onto the issuer's chart (#1869): the account each
// role books to on the document's day, the exact amount, and which side.
// It writes no journal and invents no mapping: a role with no account, a
// currency with no reviewed exponent, a tax nobody classified or a sum
// past the exact range each BLOCK the preview instead of being guessed.
//
// Pure Dart; every amount is an [AccountingAmount], never a double.

import 'accounting_amount.dart';
import 'accounting_tax.dart';
import 'book_chart.dart';

enum PostingBlock {
  /// The currency has no reviewed exponent.
  unsupportedCurrency,

  /// A role the posting needs has no mapping for the document's day.
  unmappedRole,

  /// The mapped account is gone, not a posting account, or of a type
  /// that does not fit the role.
  badAccount,

  /// A tax component nobody classified.
  unclassifiedTax,

  /// Amounts in more than one currency met in one document.
  currencyMismatch,

  /// A sum past ±(2^53 − 1) minor units.
  outOfRange,
}

class PostingBlocker {
  const PostingBlocker(this.block, this.subject);
  final PostingBlock block;

  /// The role, currency or tax the block is about.
  final String subject;

  @override
  String toString() => 'PostingBlocker(${block.name}: $subject)';
}

class PostingLine {
  const PostingLine({
    required this.role,
    required this.accountCode,
    required this.debit,
    required this.credit,
  });

  final BookRole role;
  final String accountCode;

  /// Exactly one of the two is non-zero.
  final AccountingAmount debit;
  final AccountingAmount credit;
}

class PostingPreview {
  const PostingPreview(this.lines, this.blockers);

  final List<PostingLine> lines;
  final List<PostingBlocker> blockers;

  /// True only for a preview that can be shown as a posting.
  bool get postable => blockers.isEmpty && lines.isNotEmpty;

  AccountingAmount? get totalDebit => _sum((l) => l.debit);
  AccountingAmount? get totalCredit => _sum((l) => l.credit);

  /// Debits equal credits, exactly.
  bool get balanced =>
      postable && totalDebit != null && totalDebit == totalCredit;

  AccountingAmount? _sum(AccountingAmount Function(PostingLine) pick) {
    if (lines.isEmpty) return null;
    var sum = pick(lines.first);
    for (final l in lines.skip(1)) {
      sum = sum + pick(l);
    }
    return sum;
  }
}

/// Resolves a role to an account code, or records why not.
class _Resolver {
  _Resolver(this.accounts, this.mappings, this.issuerSiteId, this.day);
  final List<BookAccount> accounts;
  final List<BookMapping> mappings;
  final String issuerSiteId;
  final DateTime day;
  final blockers = <PostingBlocker>[];

  String? code(BookRole role) {
    final m = mappingOn(mappings, issuerSiteId, role, day);
    if (m == null) {
      blockers.add(PostingBlocker(PostingBlock.unmappedRole, role.wire));
      return null;
    }
    final account = accounts.where((a) => a.id == m.accountId).firstOrNull;
    if (account == null ||
        mappingProblem(role, account, issuerSiteId) != null) {
      blockers.add(PostingBlocker(PostingBlock.badAccount, role.wire));
      return null;
    }
    return account.code;
  }
}

/// A line for [amount] on [role]: a positive amount goes to [debitSide]
/// when true, to the credit side otherwise; a negative amount (a credit
/// note, a refund) mirrors it. Zero lines are dropped.
PostingLine? _line(
  BookRole role,
  String? code,
  AccountingAmount amount, {
  required bool debitSide,
}) {
  if (code == null || amount.minor == 0) return null;
  final zero = AccountingAmount(amount.currency, 0);
  final abs = amount.minor < 0 ? -amount : amount;
  final onDebit = (amount.minor > 0) == debitSide;
  return PostingLine(
    role: role,
    accountCode: code,
    debit: onDebit ? abs : zero,
    credit: onDebit ? zero : abs,
  );
}

/// How an invoice of [net] plus [taxes] would post on [day]: customers
/// debited the gross, revenue credited the net, the output-tax account
/// credited the tax. A reverse-charge, exempt or zero-rated component
/// yields no tax line (its amount is zero). Nothing is written.
PostingPreview previewInvoicePosting({
  required AccountingAmount net,
  required List<TaxComponent> taxes,
  required String issuerSiteId,
  required DateTime day,
  required List<BookAccount> accounts,
  required List<BookMapping> mappings,
}) {
  final r = _Resolver(accounts, mappings, issuerSiteId, day);
  var tax = AccountingAmount(net.currency, 0);
  try {
    exponentOf(net.currency);
  } on AccountingException {
    return PostingPreview(const [], [
      PostingBlocker(PostingBlock.unsupportedCurrency, net.currency),
    ]);
  }
  for (final t in taxes) {
    if (t.treatment == TaxTreatment.unknown) {
      r.blockers.add(
        PostingBlocker(
          PostingBlock.unclassifiedTax,
          '${t.scheme}/${t.authority}',
        ),
      );
    } else if (t.amount.currency != net.currency) {
      r.blockers.add(
        PostingBlocker(PostingBlock.currencyMismatch, t.amount.currency),
      );
    } else {
      try {
        tax = tax + t.amount;
      } on AccountingException {
        r.blockers.add(const PostingBlocker(PostingBlock.outOfRange, 'tax'));
      }
    }
  }
  AccountingAmount gross;
  try {
    gross = net + tax;
  } on AccountingException {
    r.blockers.add(const PostingBlocker(PostingBlock.outOfRange, 'gross'));
    return PostingPreview(const [], r.blockers);
  }
  final customers = r.code(BookRole.customers);
  final revenue = r.code(BookRole.revenue);
  final vat = tax.minor == 0 ? null : r.code(BookRole.vatOutput);
  if (r.blockers.isNotEmpty) return PostingPreview(const [], r.blockers);
  return PostingPreview([
    ?_line(BookRole.customers, customers, gross, debitSide: true),
    ?_line(BookRole.revenue, revenue, net, debitSide: false),
    ?_line(BookRole.vatOutput, vat, tax, debitSide: false),
  ], const []);
}

/// How a received [payment] would post on [day]: bank debited, customers
/// credited. A negative payment (a refund) mirrors it.
PostingPreview previewPaymentPosting({
  required AccountingAmount payment,
  required String issuerSiteId,
  required DateTime day,
  required List<BookAccount> accounts,
  required List<BookMapping> mappings,
}) {
  try {
    exponentOf(payment.currency);
  } on AccountingException {
    return PostingPreview(const [], [
      PostingBlocker(PostingBlock.unsupportedCurrency, payment.currency),
    ]);
  }
  final r = _Resolver(accounts, mappings, issuerSiteId, day);
  final bank = r.code(BookRole.bank);
  final customers = r.code(BookRole.customers);
  if (r.blockers.isNotEmpty) return PostingPreview(const [], r.blockers);
  return PostingPreview([
    ?_line(BookRole.bank, bank, payment, debitSide: true),
    ?_line(BookRole.customers, customers, payment, debitSide: false),
  ], const []);
}
