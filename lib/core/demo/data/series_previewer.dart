// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- the demo's series preview: the demo booking itself, run and
// undone, as the server runs `create_series` and rolls it back.
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/series_preview.dart';

class FakeSeriesPreviewer implements SeriesPreviewer {
  const FakeSeriesPreviewer(this._reservations);

  final FakeReservationRepository _reservations;

  @override
  Future<SeriesResult> preview(SeriesAsk ask) async {
    final before = [..._reservations.reservations];
    try {
      final run = await _reservations.createSeries(
        workspaceId: ask.workspaceId,
        seatId: ask.seatId,
        deskId: ask.deskId,
        officeId: ask.officeId,
        levelId: ask.levelId,
        firstStart: ask.firstStart,
        firstEnd: ask.firstEnd,
        pattern: ask.pattern,
        until: ask.until,
      );
      return SeriesResult(
        seriesId: '',
        booked: run.booked,
        skipped: run.skipped,
      );
    } finally {
      _reservations.reservations
        ..clear()
        ..addAll(before);
    }
  }
}
