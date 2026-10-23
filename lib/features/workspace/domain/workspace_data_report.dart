// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace data report's shape: sections of tables whose cells keep
// their values and stable keys; the words and formats come in when the PDF
// is drawn. `workspace_data_report_builder.dart` fills it.

/// What a cell holds, which decides how it is printed.
enum DataReportCell {
  text,
  word,
  role,
  flag,
  money,
  count,
  day,
  month,
  hours,
  percent,
}

/// A column: its stable key (an export column key or a report key) and kind.
class DataReportColumn {
  const DataReportColumn(this.key, this.kind);

  final String key;
  final DataReportCell kind;
}

/// One table of a section: a header, its rows and, when it has one, the
/// totals row (one value per column, null where nothing is summed).
class DataReportTable {
  const DataReportTable({
    required this.key,
    required this.columns,
    required this.rows,
    this.totals,
  });

  final String key;
  final List<DataReportColumn> columns;
  final List<List<Object?>> rows;
  final List<Object?>? totals;

  /// The total printed under the column [columnKey], if any.
  Object? total(String columnKey) {
    final i = columns.indexWhere((c) => c.key == columnKey);
    return i < 0 ? null : totals?[i];
  }
}

/// The report's sections, in print order. A register is printed across.
enum DataReportPart {
  members,
  bookings,
  invoices,
  payments,
  purchases,
  plan;

  bool get landscape =>
      this == invoices || this == payments || this == purchases;
}

/// One level of the plan section: its whole-level price (null when it is
/// not bookable as a whole) and its rooms and tables.
class DataReportLevel {
  const DataReportLevel({
    required this.levelId,
    required this.name,
    required this.wholePriceCents,
    required this.table,
  });

  final String levelId;
  final String name;
  final int? wholePriceCents;
  final DataReportTable table;
}

class DataReportSection {
  const DataReportSection(
    this.part, {
    this.tables = const [],
    this.levels = const [],
  });

  final DataReportPart part;
  final List<DataReportTable> tables;
  final List<DataReportLevel> levels;
}

class WorkspaceDataReport {
  const WorkspaceDataReport({
    required this.workspaceName,
    required this.timeZone,
    required this.currency,
    required this.from,
    required this.to,
    required this.sections,
  });

  final String workspaceName;
  final String timeZone;
  final String currency;

  /// The first and last day a record of the space falls on, at the
  /// workspace's wall clock; null when it holds no dated record.
  final DateTime? from;
  final DateTime? to;
  final List<DataReportSection> sections;

  DataReportSection section(DataReportPart part) =>
      sections.firstWhere((s) => s.part == part);

  /// The table [key] wherever it is printed.
  DataReportTable table(String key) =>
      [for (final s in sections) ...s.tables].firstWhere((t) => t.key == key);
}

/// One purchase document as the report lists it; [kind] and [state] are
/// the stored words (`bill`, `credit_note`, `approved`, …).
typedef DataReportPurchase = ({
  DateTime? date,
  String reference,
  String kind,
  String state,
  String category,
  int grossCents,
});

/// One supplier as the report lists it; [status] is the stored word.
typedef DataReportSupplier = ({
  String number,
  String name,
  String taxId,
  String city,
  String country,
  String status,
});
