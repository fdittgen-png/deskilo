// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';

/// #2365 — closing a period of the books, and the log of accounting exports
/// (`book_periods`, `book_exports`, 0504). The server owns every rule: a
/// closed period refuses voids of invoices issued inside it and payments
/// dated inside it; corrections go to the open period.

enum BookPeriodReason {
  owner('owner'),
  vatFiled('vat_filed');

  const BookPeriodReason(this.wire);

  final String wire;

  static BookPeriodReason of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => owner);
}

class BookPeriod {
  const BookPeriod({
    required this.id,
    required this.from,
    required this.to,
    required this.reason,
    this.reopenedAt,
    this.reopenReason = '',
  });

  factory BookPeriod.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'book period');
    return BookPeriod(
      id: r.string('id'),
      from: DateTime.parse(r.string('period_from')),
      to: DateTime.parse(r.string('period_to')),
      reason: BookPeriodReason.of(r.stringOrNull('reason')),
      reopenedAt: DateTime.tryParse(r.stringOr('reopened_at')),
      reopenReason: r.stringOr('reopen_reason'),
    );
  }

  final String id;

  /// First and last day, both inside the period.
  final DateTime from;
  final DateTime to;
  final BookPeriodReason reason;
  final DateTime? reopenedAt;
  final String reopenReason;

  bool get closed => reopenedAt == null;

  bool contains(DateTime day) =>
      closed &&
      isoDay(day).compareTo(isoDay(from)) >= 0 &&
      isoDay(day).compareTo(isoDay(to)) <= 0;
}

/// One file handed to an accountant.
class BookExport {
  const BookExport({
    required this.id,
    required this.formatId,
    required this.from,
    required this.to,
    required this.sha256,
    required this.byteCount,
    required this.rowCount,
    required this.documentCount,
    required this.closedPeriod,
    required this.exportedAt,
  });

  factory BookExport.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'book export');
    return BookExport(
      id: r.string('id'),
      formatId: r.stringOr('format_id'),
      from: DateTime.parse(r.string('period_from')),
      to: DateTime.parse(r.string('period_to')),
      sha256: r.stringOr('sha256'),
      byteCount: r.integer('byte_count'),
      rowCount: r.integer('row_count'),
      documentCount: r.integer('document_count'),
      closedPeriod: r.boolOr('closed_period', fallback: false),
      exportedAt: DateTime.parse(r.string('exported_at')),
    );
  }

  final String id;
  final String formatId;
  final DateTime from;
  final DateTime to;
  final String sha256;
  final int byteCount;
  final int rowCount;
  final int documentCount;

  /// The whole period was closed when the file was made: asking again gives
  /// the same bytes, which the log shows as the same sha256.
  final bool closedPeriod;
  final DateTime exportedAt;
}

class BookPeriodsOverview {
  const BookPeriodsOverview({this.periods = const [], this.exports = const []});

  factory BookPeriodsOverview.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'book periods');
    return BookPeriodsOverview(
      periods: [for (final p in r.list('periods')) BookPeriod.fromJson(p)],
      exports: [for (final e in r.list('exports')) BookExport.fromJson(e)],
    );
  }

  final List<BookPeriod> periods;
  final List<BookExport> exports;

  /// The closed period that holds [day], if any.
  BookPeriod? closedOn(DateTime day) {
    for (final p in periods) {
      if (p.contains(day)) return p;
    }
    return null;
  }
}

/// A file handed out, as the log records it: the format, the period it
/// covers, and what the bytes were.
class BookExportRecord {
  const BookExportRecord({
    required this.formatId,
    required this.from,
    required this.to,
    required this.sha256,
    required this.bytes,
    required this.rows,
    required this.documents,
  });

  final String formatId;
  final DateTime from;
  final DateTime to;
  final String sha256;
  final int bytes;
  final int rows;
  final int documents;
}

/// The periods and the export log of one space; every write is an RPC.
abstract class BookPeriodRepository {
  Future<BookPeriodsOverview> fetch(String workspaceId);

  Future<BookPeriod> close(String workspaceId, DateTime from, DateTime to);

  Future<BookPeriod> reopen(String workspaceId, String periodId, String reason);

  /// Logs a file handed out: format, period, digest, size.
  Future<void> recordExport(String workspaceId, BookExportRecord record);
}
