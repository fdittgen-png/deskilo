// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — a customer's open-items statement as of a date, as the server
// answers it (`customer_statement_v1`, 0731): per currency, the documents
// still open with what is still due after their allocated parts, the parts
// as detail, the credits not yet applied, and one signed balance = still due
// − unapplied. Nothing is added across currencies.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One payment part allocated to a document by the cutoff.
class StatementAllocation {
  const StatementAllocation({
    required this.paymentId,
    required this.amountCents,
    this.on,
    this.awaitingApproval = false,
  });

  factory StatementAllocation.fromJson(JsonReader r) => StatementAllocation(
    paymentId: r.stringOr('payment_id'),
    amountCents: r.integer('amount_cents'),
    on: DateTime.tryParse(r.stringOr('on')),
    awaitingApproval: r.boolOr('awaiting_approval', fallback: false),
  );

  final String paymentId;
  final int amountCents;
  final DateTime? on;
  final bool awaitingApproval;
}

/// What a line of the statement is.
enum StatementLineState {
  open('open'),
  partlyPaid('partly_paid'),
  awaitingApproval('awaiting_approval'),
  creditNote('credit_note');

  const StatementLineState(this.wire);
  final String wire;

  static StatementLineState of(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => open);
}

/// One open document: what is still due on it at the cutoff (negative for
/// a credit note: the business owes it) and the parts that settled it.
class StatementLine {
  const StatementLine({
    required this.invoiceId,
    required this.number,
    required this.totalCents,
    required this.stillDueCents,
    required this.state,
    this.issuedAt,
    this.dueOn,
    this.allocations = const [],
  });

  factory StatementLine.fromJson(JsonReader r) => StatementLine(
    invoiceId: r.string('invoice_id'),
    number: r.stringOr('number'),
    totalCents: r.integer('total_cents'),
    stillDueCents: r.integer('still_due_cents'),
    state: StatementLineState.of(r.stringOr('state')),
    issuedAt: DateTime.tryParse(r.stringOr('issued_at')),
    dueOn: DateTime.tryParse(r.stringOr('due_on')),
    allocations: r.objects('allocations', StatementAllocation.fromJson),
  );

  final String invoiceId;
  final String number;
  final int totalCents;
  final int stillDueCents;
  final StatementLineState state;
  final DateTime? issuedAt;
  final DateTime? dueOn;
  final List<StatementAllocation> allocations;
}

/// A credit or a payment remainder not yet applied.
class StatementCredit {
  const StatementCredit({
    required this.ledgerId,
    required this.leftCents,
    this.category = '',
    this.description = '',
    this.on,
  });

  factory StatementCredit.fromJson(JsonReader r) => StatementCredit(
    ledgerId: r.string('ledger_id'),
    leftCents: r.integer('left_cents'),
    category: r.stringOr('category'),
    description: r.stringOr('description'),
    on: DateTime.tryParse(r.stringOr('on')),
  );

  final String ledgerId;
  final int leftCents;
  final String category;
  final String description;
  final DateTime? on;
}

/// The statement in one currency.
class StatementCurrency {
  const StatementCurrency({
    required this.currency,
    required this.stillDueCents,
    required this.unappliedCents,
    required this.balanceCents,
    this.lines = const [],
    this.credits = const [],
  });

  factory StatementCurrency.fromJson(JsonReader r) => StatementCurrency(
    currency: r.string('currency'),
    stillDueCents: r.integer('still_due_cents'),
    unappliedCents: r.integer('unapplied_cents'),
    balanceCents: r.integer('balance_cents'),
    lines: r.objects('invoices', StatementLine.fromJson),
    credits: r.objects('credits', StatementCredit.fromJson),
  );

  final String currency;

  /// Σ still due of [lines] (credit notes negative).
  final int stillDueCents;

  /// Σ left of [credits].
  final int unappliedCents;

  /// [stillDueCents] − [unappliedCents]: positive, the customer owes it;
  /// negative, the business does.
  final int balanceCents;
  final List<StatementLine> lines;
  final List<StatementCredit> credits;
}

/// A customer's statement as of [asOf].
class CustomerStatement {
  const CustomerStatement({
    required this.memberId,
    required this.asOf,
    this.currencies = const [],
  });

  factory CustomerStatement.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'customer statement');
    return CustomerStatement(
      memberId: r.string('member_id'),
      asOf: DateTime.parse(r.string('as_of')),
      currencies: r.objects('currencies', StatementCurrency.fromJson),
    );
  }

  final String memberId;
  final DateTime asOf;

  /// One statement per currency, by code.
  final List<StatementCurrency> currencies;
}

/// One [StatementCurrency] per currency of [lines] and [credits], by code,
/// each with its totals: still due (credit notes negative), unapplied, and
/// the balance = still due − unapplied. Nothing is added across currencies.
List<StatementCurrency> statementCurrencies({
  required Map<String, List<StatementLine>> lines,
  required Map<String, List<StatementCredit>> credits,
}) {
  final codes = {...lines.keys, ...credits.keys}.toList()..sort();
  return [
    for (final code in codes)
      () {
        final mine = lines[code] ?? const <StatementLine>[];
        final left = credits[code] ?? const <StatementCredit>[];
        final due = mine.fold(0, (sum, l) => sum + l.stillDueCents);
        final unapplied = left.fold(0, (sum, c) => sum + c.leftCents);
        return StatementCurrency(
          currency: code,
          stillDueCents: due,
          unappliedCents: unapplied,
          balanceCents: due - unapplied,
          lines: mine,
          credits: left,
        );
      }(),
  ];
}

/// The server's side of the statement.
abstract interface class CustomerStatementReader {
  /// [memberId]'s statement in [workspaceId] as of [asOf] (a calendar day).
  Future<CustomerStatement> read(
    String workspaceId,
    String memberId,
    DateTime asOf,
  );
}
