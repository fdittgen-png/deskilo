// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/book_period.dart';
import '../domain/fiscal_year.dart';

/// #2365 — what is sent for the book periods. A command sends nothing when
/// the entry cannot be right (the server decides again on every write); null
/// tells the caller nothing was sent.
class BookPeriodCommands {
  const BookPeriodCommands(this._repository);

  final BookPeriodRepository _repository;

  /// A period that ends before it starts, or that has not ended, is not sent.
  Future<BookPeriod?> close(
    String workspaceId,
    DateTime from,
    DateTime to,
    DateTime today,
  ) async {
    final lastDay = DateTime(today.year, today.month, today.day);
    if (to.isBefore(from) || to.isAfter(lastDay)) return null;
    return _repository.close(workspaceId, from, to);
  }

  /// Logs a file already handed out for the calendar year [year], or for
  /// [period] when given (#2376: a FEC covers its fiscal year):
  /// format, size and sha256. The file is the accountant's already, so a
  /// failed log is traced and never turns the export into a failure.
  /// Answers the log row's id, null when nothing was logged.
  Future<String?> logExport(
    String workspaceId, {
    required String formatId,
    required int year,
    required String content,
    required int documents,
    FiscalYear? period,
  }) => _record(
    workspaceId,
    utf8.encode(content),
    BookExportRecord(
      formatId: formatId,
      from: period?.from ?? DateTime(year),
      to: period?.to ?? DateTime(year, 12, 31),
      sha256: '',
      bytes: 0,
      rows: const LineSplitter().convert(content).length,
      documents: documents,
    ),
  );

  /// #2377 — the export log of the calendar [year], each file with who
  /// made it and when: what the audit trail lists as accesses (GeBüV
  /// art. 8). A log that cannot be read fails the trail, never shortens it.
  Future<List<BookExport>> exportLog(String workspaceId, int year) =>
      _repository.fetchExportLog(
        workspaceId,
        DateTime(year),
        DateTime(year, 12, 31),
      );

  /// [logExport] for a file of [bytes] (a zip) of the calendar [year]
  /// holding [rows] records.
  Future<String?> logExportBytes(
    String workspaceId, {
    required String formatId,
    required int year,
    required List<int> bytes,
    required int rows,
    required int documents,
  }) => _record(
    workspaceId,
    bytes,
    BookExportRecord(
      formatId: formatId,
      from: DateTime(year),
      to: DateTime(year, 12, 31),
      sha256: '',
      bytes: 0,
      rows: rows,
      documents: documents,
    ),
  );

  /// Records [what] with the digest and size of [bytes].
  Future<String?> _record(
    String workspaceId,
    List<int> bytes,
    BookExportRecord what,
  ) async {
    try {
      return await _repository.recordExport(
        workspaceId,
        BookExportRecord(
          formatId: what.formatId,
          from: what.from,
          to: what.to,
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          rows: what.rows,
          documents: what.documents,
        ),
      );
    } on Exception catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'the accounting export was not logged',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Reopening states why.
  Future<BookPeriod?> reopen(
    String workspaceId,
    BookPeriod period,
    String reason,
  ) async {
    if (!period.closed || reason.trim().isEmpty) return null;
    return _repository.reopen(workspaceId, period.id, reason.trim());
  }
}
