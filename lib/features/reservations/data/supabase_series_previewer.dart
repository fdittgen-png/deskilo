// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- the series preview on the workspace's own server: the booking
// itself, run and rolled back (`preview_series`, 0514).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reservation_repository.dart';
import '../domain/series_preview.dart';

class SupabaseSeriesPreviewer implements SeriesPreviewer {
  const SupabaseSeriesPreviewer(this._client);

  final SupabaseClient _client;

  @override
  Future<SeriesResult> preview(SeriesAsk ask) async {
    final answer = await _client.rpc<Map<String, Object?>>(
      'preview_series',
      params: {
        'p_workspace_id': ask.workspaceId,
        'p_seat_id': ask.seatId,
        'p_desk_id': ask.deskId,
        'p_office_id': ask.officeId,
        'p_level_id': ask.levelId,
        'p_first_start': ask.firstStart.toUtc().toIso8601String(),
        'p_first_end': ask.firstEnd.toUtc().toIso8601String(),
        'p_pattern': ask.pattern.name,
        'p_until': ask.until.toUtc().toIso8601String(),
      },
    );
    List<DateTime> dates(String key) => [
      for (final v in answer[key]! as List<Object?>)
        DateTime.parse(v! as String),
    ];
    return SeriesResult(
      seriesId: '',
      booked: dates('booked'),
      skipped: dates('skipped'),
    );
  }
}
