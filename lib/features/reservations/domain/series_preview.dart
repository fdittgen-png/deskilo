// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- a series preview: which dates of a repeat would book and which
// would fail, asked BEFORE the person submits, so a partial series is a
// choice and never a surprise (spec §5.2). The server answers with its own
// booking run and rolled back (`preview_series`, 0514).
//
// Pure Dart.
import 'reservation_repository.dart';

/// One repeat as the person asked for it: exactly one of [seatId],
/// [deskId], [officeId] or [levelId].
class SeriesAsk {
  const SeriesAsk({
    required this.workspaceId,
    required this.firstStart,
    required this.firstEnd,
    required this.pattern,
    required this.until,
    this.seatId,
    this.deskId,
    this.officeId,
    this.levelId,
  });

  final String workspaceId;
  final String? seatId;
  final String? deskId;
  final String? officeId;
  final String? levelId;
  final DateTime firstStart;
  final DateTime firstEnd;
  final SeriesPattern pattern;
  final DateTime until;
}

/// Answers which dates of a series would book, writing nothing.
abstract interface class SeriesPreviewer {
  /// [SeriesResult.booked] would book, [SeriesResult.skipped] would fail;
  /// [SeriesResult.seriesId] is empty: no series exists.
  Future<SeriesResult> preview(SeriesAsk ask);
}
