// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3839 — a customer's statement for a period, as the server answers it
// (`customer_statement_period_v1`, 0751): per currency, the opening balance,
// every movement of the period and the closing balance; nothing is added
// across currencies. The opening and the closing are the open-items
// statement of the day before the period and of its last day; each movement
// is what changed between two readings of the open items, at the instant of
// the decision that made it count, so opening + movements = closing.
// [statementPeriodOf] is that construction, for a reader without the
// server (the Demo).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'customer_statement.dart';

/// What a movement was.
enum PeriodMovementWhat {
  invoice('invoice'),
  creditNote('credit_note'),
  voided('voided'),
  settled('settled'),
  reopened('reopened'),
  writtenOff('written_off'),
  paid('paid'),
  payment('payment'),
  credit('credit'),
  moved('moved'),
  applied('applied'),
  freed('freed'),
  allocated('allocated');

  const PeriodMovementWhat(this.wire);
  final String wire;

  static PeriodMovementWhat of(String wire) =>
      values.firstWhere((w) => w.wire == wire, orElse: () => paid);
}

/// One movement: its effect on the balance (positive, the customer owes
/// more), the day of the decision that made it count, and the document's or
/// the payment's own day.
class PeriodMovement {
  const PeriodMovement({
    required this.decidedOn,
    required this.label,
    required this.what,
    required this.amountCents,
    this.ownOn,
  });

  factory PeriodMovement.fromJson(JsonReader r) => PeriodMovement(
    decidedOn: DateTime.parse(r.string('decided_on')),
    ownOn: DateTime.tryParse(r.stringOr('own_on')),
    label: r.stringOr('label'),
    what: PeriodMovementWhat.of(r.stringOr('what')),
    amountCents: r.integer('amount_cents'),
  );

  final DateTime decidedOn;
  final DateTime? ownOn;
  final String label;
  final PeriodMovementWhat what;
  final int amountCents;

  /// The own day differs from the day it counted ("payment of 28 Oct,
  /// confirmed 3 Nov").
  bool get datedApart {
    final own = ownOn;
    return own != null &&
        (own.year, own.month, own.day) !=
            (decidedOn.year, decidedOn.month, decidedOn.day);
  }
}

/// The period in one currency.
class PeriodCurrency {
  const PeriodCurrency({
    required this.currency,
    required this.openingCents,
    required this.closingCents,
    this.movements = const [],
  });

  factory PeriodCurrency.fromJson(JsonReader r) => PeriodCurrency(
    currency: r.string('currency'),
    openingCents: r.integer('opening_cents'),
    closingCents: r.integer('closing_cents'),
    movements: r.objects('movements', PeriodMovement.fromJson),
  );

  final String currency;
  final int openingCents;
  final int closingCents;
  final List<PeriodMovement> movements;
}

/// A customer's statement from [from] to [to], both days included.
class CustomerStatementPeriod {
  const CustomerStatementPeriod({
    required this.memberId,
    required this.from,
    required this.to,
    this.historyFrom,
    this.reconstructedBefore = false,
    this.currencies = const [],
  });

  factory CustomerStatementPeriod.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'customer statement period');
    return CustomerStatementPeriod(
      memberId: r.string('member_id'),
      from: DateTime.parse(r.string('from')),
      to: DateTime.parse(r.string('to')),
      historyFrom: DateTime.tryParse(r.stringOr('history_from')),
      reconstructedBefore: r.boolOr('reconstructed_before', fallback: false),
      currencies: r.objects('currencies', PeriodCurrency.fromJson),
    );
  }

  final String memberId;
  final DateTime from;
  final DateTime to;

  /// From when the business's match history is exact (0750).
  final DateTime? historyFrom;

  /// The period starts before [historyFrom]: its balances before that day
  /// are reconstructed from today's records, and the document says so.
  final bool reconstructedBefore;
  final List<PeriodCurrency> currencies;
}

/// Each open item of [statement] by currency and key, with its effect on the
/// balance: a document's still due, a credit's left as a negative.
Map<
  String,
  ({
    String currency,
    int cents,
    String label,
    DateTime? on,
    String category,
    bool document,
    int total,
  })
>
_items(CustomerStatement statement) => {
  for (final c in statement.currencies) ...{
    for (final l in c.lines)
      '${c.currency}|d|${l.invoiceId}': (
        currency: c.currency,
        cents: l.stillDueCents,
        label: l.number,
        on: l.issuedAt,
        category: '',
        document: true,
        total: l.totalCents,
      ),
    for (final k in c.credits)
      '${c.currency}|c|${k.ledgerId}': (
        currency: c.currency,
        cents: -k.leftCents,
        label: k.description,
        on: k.on,
        category: k.category,
        document: false,
        total: 0,
      ),
  },
};

/// What a changed item was: a document issued on that day, or open again,
/// or paid; a credit received on that day, or freed, or allocated.
PeriodMovementWhat _what(
  ({
    String currency,
    int cents,
    String label,
    DateTime? on,
    String category,
    bool document,
    int total,
  })
  it,
  int was,
  int now,
  DateTime at,
) {
  final on = it.on;
  final appeared =
      was == 0 &&
      on != null &&
      (on.year, on.month, on.day) == (at.year, at.month, at.day);
  final grew = now.abs() > was.abs();
  if (it.document) {
    if (appeared) {
      return it.total < 0
          ? PeriodMovementWhat.creditNote
          : PeriodMovementWhat.invoice;
    }
    return grew ? PeriodMovementWhat.reopened : PeriodMovementWhat.paid;
  }
  if (appeared) {
    return it.category == 'payment'
        ? PeriodMovementWhat.payment
        : PeriodMovementWhat.credit;
  }
  return grew ? PeriodMovementWhat.freed : PeriodMovementWhat.allocated;
}

/// The movements between two readings, at [at]: each item whose effect
/// changed, by how much, and what it was.
List<({String currency, PeriodMovement movement})> _between(
  CustomerStatement before,
  CustomerStatement after,
  DateTime at,
) {
  final p = _items(before);
  final n = _items(after);
  return [
    for (final key in {...p.keys, ...n.keys}.toList()..sort())
      if ((p[key]?.cents ?? 0) != (n[key]?.cents ?? 0))
        (
          currency: (n[key] ?? p[key])!.currency,
          movement: PeriodMovement(
            decidedOn: at,
            ownOn: (n[key] ?? p[key])!.on,
            label: (n[key] ?? p[key])!.label,
            what: _what(
              (n[key] ?? p[key])!,
              p[key]?.cents ?? 0,
              n[key]?.cents ?? 0,
              at,
            ),
            amountCents: (n[key]?.cents ?? 0) - (p[key]?.cents ?? 0),
          ),
        ),
  ];
}

int _balance(CustomerStatement s, String currency) =>
    s.currencies
        .where((c) => c.currency == currency)
        .firstOrNull
        ?.balanceCents ??
    0;

/// The period from [opening] (the open items at the start of [from]),
/// through [steps] (the open items just after each instant at which
/// something changed, in order), to [closing] (the end of [to]): the same
/// construction as the server's, so opening + movements = closing.
CustomerStatementPeriod statementPeriodOf({
  required DateTime from,
  required DateTime to,
  required CustomerStatement opening,
  required List<(DateTime, CustomerStatement)> steps,
  required CustomerStatement closing,
  DateTime? historyFrom,
}) {
  final moves = <String, List<PeriodMovement>>{};
  var previous = opening;
  for (final (at, reading) in [...steps, (to, closing)]) {
    for (final m in _between(previous, reading, at)) {
      (moves[m.currency] ??= []).add(m.movement);
    }
    previous = reading;
  }
  final codes = {
    for (final c in opening.currencies) c.currency,
    for (final c in closing.currencies) c.currency,
    ...moves.keys,
  }.toList()..sort();
  return CustomerStatementPeriod(
    memberId: opening.memberId,
    from: from,
    to: to,
    historyFrom: historyFrom,
    reconstructedBefore: historyFrom != null && from.isBefore(historyFrom),
    currencies: [
      for (final code in codes)
        PeriodCurrency(
          currency: code,
          openingCents: _balance(opening, code),
          closingCents: _balance(closing, code),
          movements: moves[code] ?? const [],
        ),
    ],
  );
}
