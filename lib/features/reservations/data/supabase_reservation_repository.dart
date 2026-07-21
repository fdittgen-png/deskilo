// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

class SupabaseReservationRepository implements ReservationRepository {
  SupabaseReservationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('reservations')
        .select()
        .eq('workspace_id', workspaceId)
        .lt('starts_at', to.toUtc().toIso8601String())
        .gt('ends_at', from.toUtc().toIso8601String())
        .order('starts_at', ascending: true);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) async {
    final result = await _client.rpc<dynamic>('create_reservation', params: {
      'p_workspace_id': workspaceId,
      'p_seat_id': seatId,
      'p_office_id': officeId,
      'p_level_id': levelId,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
      'p_check_in': checkIn,
    });
    return result as String;
  }

  @override
  Future<String> createFor({
    required String workspaceId,
    required String subjectMemberId,
    String? seatId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final result =
        await _client.rpc<dynamic>('admin_create_reservation_for', params: {
      'p_workspace_id': workspaceId,
      'p_subject_member_id': subjectMemberId,
      'p_seat_id': seatId,
      'p_level_id': levelId,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
    });
    return result as String;
  }

  @override
  Future<void> checkIn(String reservationId) async {
    await _client.rpc<dynamic>('check_in_reservation', params: {
      'p_reservation_id': reservationId,
    });
  }

  @override
  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    String? levelId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final result = await _client.rpc<dynamic>('kiosk_act', params: {
      'p_workspace_id': workspaceId,
      'p_badge_token': badgeToken,
      'p_action': action,
      'p_seat_id': ?seatId,
      'p_level_id': ?levelId,
      'p_starts_at': ?startsAt?.toUtc().toIso8601String(),
      'p_ends_at': ?endsAt?.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return result['reservation_id'] as String;
  }

  @override
  Future<void> checkOut(String reservationId) async {
    await _client.rpc<dynamic>('check_out_reservation', params: {
      'p_reservation_id': reservationId,
    });
  }

  @override
  Future<void> cancel(String reservationId) async {
    await _client.rpc<dynamic>('cancel_reservation', params: {
      'p_reservation_id': reservationId,
    });
  }

  @override
  Future<void> updateTimes(
    String reservationId, {
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await _client.rpc<dynamic>('update_reservation', params: {
      'p_reservation_id': reservationId,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<SeriesResult> createSeries({
    required String workspaceId,
    required String seatId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  }) async {
    final result = await _client.rpc<dynamic>('create_series', params: {
      'p_workspace_id': workspaceId,
      'p_seat_id': seatId,
      'p_first_start': firstStart.toUtc().toIso8601String(),
      'p_first_end': firstEnd.toUtc().toIso8601String(),
      'p_pattern': pattern.name,
      'p_until': until.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    List<DateTime> dates(String key) => (result[key] as List<dynamic>)
        .map((v) => DateTime.parse(v as String))
        .toList();
    return SeriesResult(
      seriesId: result['series_id'] as String,
      booked: dates('booked'),
      skipped: dates('skipped'),
    );
  }

  @override
  Future<int> cancelSeries(String seriesId, {DateTime? from}) async {
    final result = await _client.rpc<dynamic>('cancel_series', params: {
      'p_series_id': seriesId,
      'p_from': from?.toUtc().toIso8601String(),
    });
    return result as int;
  }

  Reservation _fromRow(Map<String, dynamic> row) => Reservation(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        seatId: row['seat_id'] as String?,
        officeId: row['office_id'] as String?,
        levelId: row['level_id'] as String?,
        memberId: row['member_id'] as String,
        startsAt: DateTime.parse(row['starts_at'] as String),
        endsAt: DateTime.parse(row['ends_at'] as String),
        status: reservationStatusFromDb(row['status'] as String),
        seriesId: row['series_id'] as String?,
        seriesPattern: row['series_pattern'] as String?,
        checkedInAt: row['checked_in_at'] == null
            ? null
            : DateTime.parse(row['checked_in_at'] as String),
        checkedOutAt: row['checked_out_at'] == null
            ? null
            : DateTime.parse(row['checked_out_at'] as String),
      );
}
