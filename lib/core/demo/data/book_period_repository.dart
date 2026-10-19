// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/book_period.dart';

/// #2365 — the book periods in memory, with the server's rules the screen
/// shows: a period closes once, never overlaps another closed one, ends no
/// later than today, and reopens with a reason.
class FakeBookPeriodRepository implements BookPeriodRepository {
  FakeBookPeriodRepository({
    required this.today,
    Iterable<BookPeriod> periods = const [],
    Iterable<BookExport> exports = const [],
  }) : periods = [...periods],
       exports = [...exports];

  final DateTime today;
  final List<BookPeriod> periods;
  final List<BookExport> exports;
  var _next = 1;

  @override
  Future<BookPeriodsOverview> fetch(String workspaceId) async =>
      BookPeriodsOverview(periods: [...periods], exports: [...exports]);

  @override
  Future<BookPeriod> close(String workspaceId, DateTime from, DateTime to) async {
    if (to.isBefore(from)) throw StateError('the period ends before it starts');
    if (to.isAfter(DateTime(today.year, today.month, today.day))) {
      throw StateError('a period that has not ended cannot be closed');
    }
    if (periods.any((p) => p.closed && !to.isBefore(p.from) && !from.isAfter(p.to))) {
      throw StateError('part of this period is already closed');
    }
    final period = BookPeriod(
      id: 'demo-period-${_next++}',
      from: from,
      to: to,
      reason: BookPeriodReason.owner,
    );
    periods.add(period);
    return period;
  }

  @override
  Future<BookPeriod> reopen(String workspaceId, String periodId, String reason) async {
    final i = periods.indexWhere((p) => p.id == periodId);
    if (i < 0) throw StateError('unknown period');
    if (reason.trim().isEmpty) throw StateError('say why the period is reopened');
    final p = periods[i];
    return periods[i] = BookPeriod(
      id: p.id,
      from: p.from,
      to: p.to,
      reason: p.reason,
      reopenedAt: today,
      reopenReason: reason.trim(),
    );
  }

  @override
  Future<void> recordExport(String workspaceId, BookExportRecord record) async {
    final closed = periods.any(
      (p) => p.closed && !record.from.isBefore(p.from) && !record.to.isAfter(p.to),
    );
    exports.insert(
      0,
      BookExport(
        id: 'demo-export-${_next++}',
        formatId: record.formatId,
        from: record.from,
        to: record.to,
        sha256: record.sha256,
        byteCount: record.bytes,
        rowCount: record.rows,
        documentCount: record.documents,
        closedPeriod: closed,
        exportedAt: today,
      ),
    );
  }
}
