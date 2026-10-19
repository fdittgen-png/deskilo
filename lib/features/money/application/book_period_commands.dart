// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/book_period.dart';

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

  /// Logs a file already handed out for the calendar year [year]: format,
  /// size and sha256. The file is the accountant's already, so a failed log is
  /// traced and never turns the export into a failure.
  Future<void> logExport(
    String workspaceId, {
    required String formatId,
    required int year,
    required String content,
    required int documents,
  }) async {
    final bytes = utf8.encode(content);
    try {
      await _repository.recordExport(
        workspaceId,
        BookExportRecord(
          formatId: formatId,
          from: DateTime(year),
          to: DateTime(year, 12, 31),
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          rows: const LineSplitter().convert(content).length,
          documents: documents,
        ),
      );
    } on Exception catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'the accounting export was not logged',
        error: e,
        stackTrace: st,
      );
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
