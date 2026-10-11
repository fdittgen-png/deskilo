// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — a filed VAT period is LOCKED (ADR 0039). What its tax points
// amount to may still change after the filing — an invoice voided, a
// payment recorded late with an earlier date — but the filed return
// never does: the difference is declared as a CORRECTION in the next
// return, naming the return it corrects (FR CA3 lines 15/21, DE § 17
// UStG in the period of the change, UK error correction on the next
// return).
//
// The SQL twin is `vat_return_lines` (0403): the return of a period is
// its own tax points that no filed return of another period covers,
// then, for every filed period that ended before it, what those tax
// points amount to now minus what the filed returns declared for them
// (`vat_return_entries`, written by each filing — including the
// corrections it carried, so a change is corrected once).
// `vat_return_parity_test.dart` pins both to one fixture.
import 'vat_tax_point.dart';

/// A filed return's period: the tax points inside it are locked.
class VatPeriodLock {
  const VatPeriodLock({
    required this.declarationId,
    required this.start,
    required this.end,
    required this.filedAt,
  });

  final String declarationId;
  final DateTime start;
  final DateTime end;
  final DateTime filedAt;

  /// Whether [day] lies in the locked period, both ends inclusive.
  bool covers(DateTime day) => !day.isBefore(start) && !day.isAfter(end);

  bool _is(DateTime from, DateTime to) => start == from && end == to;
}

/// One amount a filed return declared for one document at one tax point
/// and rate (a `vat_return_entries` row).
class VatDeclaredAmount {
  const VatDeclaredAmount({
    required this.invoiceId,
    required this.on,
    required this.percent,
    required this.grossCents,
    required this.netCents,
  });

  final String invoiceId;
  final DateTime on;
  final double percent;
  final int grossCents;
  final int netCents;
}

/// One amount of a return: the period's own, or a correction of the
/// filed return [corrects] names.
class VatReturnAmount {
  const VatReturnAmount({
    required this.invoiceId,
    required this.on,
    required this.percent,
    required this.grossCents,
    required this.netCents,
    this.corrects = '',
  });

  final String invoiceId;

  /// The tax point; a correction keeps the one in the filed period.
  final DateTime on;
  final double percent;
  final int grossCents;
  final int netCents;
  final String corrects;

  int get vatCents => grossCents - netCents;
  bool get isCorrection => corrects.isNotEmpty;
}

/// The amounts the return of [start]..[end] declares, given the whole
/// [ledger] (`vatTaxPointLedger`), the [locks] of the filed returns and
/// what they [declared].
List<VatReturnAmount> vatReturnAmountsOf(
  Iterable<VatTaxPointAmount> ledger, {
  required DateTime start,
  required DateTime end,
  List<VatPeriodLock> locks = const [],
  List<VatDeclaredAmount> declared = const [],
}) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  final earlier = [
    for (final l in locks)
      if (l.end.isBefore(from)) l,
  ]..sort((a, b) {
      final byFiling = a.filedAt.compareTo(b.filedAt);
      return byFiling != 0
          ? byFiling
          : a.declarationId.compareTo(b.declarationId);
    });
  bool lockedElsewhere(DateTime day) =>
      locks.any((l) => l.covers(day) && !l._is(from, to));
  VatPeriodLock? correcting(DateTime day) =>
      earlier.where((l) => l.covers(day)).firstOrNull;

  final out = <VatReturnAmount>[];
  final delta = <(String, DateTime, double), (int, int)>{};
  void add(String id, DateTime on, double percent, int gross, int net) {
    final key = (id, on, percent);
    final seen = delta[key] ?? (0, 0);
    delta[key] = (seen.$1 + gross, seen.$2 + net);
  }

  for (final a in ledger) {
    if (a.within(from, to) && !lockedElsewhere(a.on)) {
      out.add(VatReturnAmount(
        invoiceId: a.invoiceId,
        on: a.on,
        percent: a.percent,
        grossCents: a.grossCents,
        netCents: a.netCents,
      ));
    }
    if (correcting(a.on) != null) {
      add(a.invoiceId, a.on, a.percent, a.grossCents, a.netCents);
    }
  }
  for (final d in declared) {
    if (correcting(d.on) != null) {
      add(d.invoiceId, d.on, d.percent, -d.grossCents, -d.netCents);
    }
  }
  for (final MapEntry(key: k, value: v) in delta.entries) {
    if (v.$1 == 0 && v.$2 == 0) continue;
    out.add(VatReturnAmount(
      invoiceId: k.$1,
      on: k.$2,
      percent: k.$3,
      grossCents: v.$1,
      netCents: v.$2,
      corrects: correcting(k.$2)!.declarationId,
    ));
  }
  return out;
}

/// What filing a return of [amounts] records: one entry per document,
/// tax point and rate, the corrections included.
List<VatDeclaredAmount> vatDeclaredBy(Iterable<VatReturnAmount> amounts) {
  final sums = <(String, DateTime, double), (int, int)>{};
  for (final a in amounts) {
    final key = (a.invoiceId, a.on, a.percent);
    final seen = sums[key] ?? (0, 0);
    sums[key] = (seen.$1 + a.grossCents, seen.$2 + a.netCents);
  }
  return [
    for (final MapEntry(key: k, value: v) in sums.entries)
      VatDeclaredAmount(
        invoiceId: k.$1,
        on: k.$2,
        percent: k.$3,
        grossCents: v.$1,
        netCents: v.$2,
      ),
  ];
}
