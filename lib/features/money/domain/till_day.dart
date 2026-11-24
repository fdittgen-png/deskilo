// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 (CS5) -- the day close: once every till is closed, someone who may see the finances closes the day into one
// numbered, immutable business record. The server (`counter_day_close_v1`, `counter_day_report_v1`) builds the report;
// this file is what it answers. It is the business record only: the legal content a country requires of a day close comes
// with its own adapter. Amounts are MINOR units, sent as text.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

int _minor(JsonReader r, String key) => int.parse('${r.raw(key)}');

Map<String, int> _byKind(JsonReader r, String key) {
  final raw = r.objectOrEmpty(key);
  return {for (final e in raw.entries) e.key: int.parse('${e.value}')};
}

/// One closed session of the day: what the drawer should have held, what was counted and why it differs.
class DaySession {
  const DaySession({
    required this.till,
    required this.floatMinor,
    required this.expectedMinor,
    required this.countedMinor,
    required this.differenceMinor,
    required this.differenceReason,
    required this.bankedMinor,
    required this.unresolvedCardMinor,
  });

  final String till;
  final int floatMinor;
  final int expectedMinor;
  final int countedMinor;
  final int differenceMinor;

  /// Empty when the count matched.
  final String differenceReason;
  final int bankedMinor;
  final int unresolvedCardMinor;

  factory DaySession.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_day_report.sessions');
    return DaySession(
      till: r.stringOr('till'),
      floatMinor: _minor(r, 'float_minor'),
      expectedMinor: _minor(r, 'expected_minor'),
      countedMinor: _minor(r, 'counted_minor'),
      differenceMinor: _minor(r, 'difference_minor'),
      differenceReason: r.stringOr('difference_reason'),
      bankedMinor: _minor(r, 'banked_minor'),
      unresolvedCardMinor: _minor(r, 'unresolved_card_minor'),
    );
  }
}

/// The sales of one tax rate and category.
class DayRate {
  const DayRate({required this.percent, required this.category, required this.grossMinor, required this.netMinor, required this.taxMinor});

  /// The rate as the server wrote it (`20`, `5.5`).
  final String percent;
  final String category;
  final int grossMinor;
  final int netMinor;
  final int taxMinor;

  factory DayRate.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_day_report.sales_by_rate');
    return DayRate(
      percent: '${r.raw('percent')}',
      category: r.stringOr('category'),
      grossMinor: _minor(r, 'gross_minor'),
      netMinor: _minor(r, 'net_minor'),
      taxMinor: _minor(r, 'tax_minor'),
    );
  }
}

/// A day's report.
class DayReport {
  const DayReport({
    required this.dayCloseId,
    required this.number,
    required this.businessDate,
    required this.sessions,
    required this.differencesMinor,
    required this.salesByRate,
    required this.salesByTender,
    required this.salesTotalMinor,
    required this.firstReceipt,
    required this.lastReceipt,
    required this.correctionsMinor,
    required this.refunds,
    required this.paidInMinor,
    required this.paidOutMinor,
  });

  final String dayCloseId;
  final String number;

  /// `YYYY-MM-DD`, the business's own calendar.
  final String businessDate;
  final List<DaySession> sessions;
  final int differencesMinor;
  final List<DayRate> salesByRate;

  /// Accepted tenders by kind (`cash`, `card`, ...).
  final Map<String, int> salesByTender;
  final int salesTotalMinor;

  /// The range of the receipt numbers of the day; empty when nothing was sold.
  final String firstReceipt;
  final String lastReceipt;
  final int correctionsMinor;

  /// Refunds by kind.
  final Map<String, int> refunds;
  final int paidInMinor;
  final int paidOutMinor;

  int get unresolvedCardMinor => sessions.fold(0, (a, s) => a + s.unresolvedCardMinor);

  /// [json] is either `counter_day_close_v1`'s answer (the report under `report`) or `counter_day_report_v1`'s.
  factory DayReport.fromJson(Object? json) {
    final top = JsonReader.of(json, context: 'counter_day_report');
    final r = top.objectOrAbsent('report');
    final receipts = r.objectOrAbsent('receipts');
    final corrections = r.objectOrAbsent('corrections');
    return DayReport(
      dayCloseId: top.string('day_close_id'),
      number: top.stringOr('number'),
      businessDate: top.stringOrNull('business_date') ?? r.stringOr('business_date'),
      sessions: [for (final s in r.listOrAbsent('sessions')) DaySession.fromJson(s)],
      differencesMinor: _minor(r, 'differences_minor'),
      salesByRate: [for (final x in r.listOrAbsent('sales_by_rate')) DayRate.fromJson(x)],
      salesByTender: _byKind(r, 'sales_by_tender'),
      salesTotalMinor: _minor(r, 'sales_total_minor'),
      firstReceipt: receipts.stringOr('first'),
      lastReceipt: receipts.stringOr('last'),
      correctionsMinor: corrections.raw('total_minor') == null ? 0 : _minor(corrections, 'total_minor'),
      refunds: _byKind(r, 'refunds'),
      paidInMinor: _minor(r, 'paid_in_minor'),
      paidOutMinor: _minor(r, 'paid_out_minor'),
    );
  }
}

/// A day close as the list shows it.
class DayCloseRow {
  const DayCloseRow({required this.id, required this.number, required this.businessDate});

  final String id;
  final String number;
  final String businessDate;

  factory DayCloseRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_day_closes');
    return DayCloseRow(id: r.string('id'), number: r.stringOr('number'), businessDate: r.string('business_date'));
  }
}
