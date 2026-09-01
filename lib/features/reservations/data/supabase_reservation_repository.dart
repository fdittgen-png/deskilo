// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cached_fetch.dart';

import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';
import '../../../core/trace/act_trace.dart';
import '../../../core/trace/trace_logger.dart';

class SupabaseReservationRepository implements ReservationRepository {
  SupabaseReservationRepository(this._client, this._cache);

  final SupabaseClient _client;

  /// Reservations are LIVE data: the network stays primary and the
  /// cache only answers when it fails (the tankstellen offline
  /// backbone) — a stale answer online would mislead a booking.
  final CacheStore _cache;

  /// Every mutation drops the cached windows: an offline fallback must
  /// never resurrect a pre-mutation view.
  Future<void> _bust() => _cache.invalidatePrefix('resv:');

  /// #791 — every booking mutation leaves three possible lines in the
  /// trace: requested, accepted, or failed with its exception.
  ///
  /// The pair matters more than either half. A report of "check-in did
  /// nothing" is answered completely differently depending on whether the
  /// log holds `check-in requested` (the app asked and the server refused
  /// or hung) or holds nothing at all (the app never asked — the decision
  /// was made on the device, and the decision traces upstream say why).
  Future<T> _traced<T>(
    String act,
    Map<String, Object?> fields,
    Future<T> Function() body,
  ) async {
    ActTrace.booking.step('$act requested', fields);
    try {
      final result = await body();
      ActTrace.booking.step('$act accepted', fields);
      return result;
    } catch (e, st) {
      ActTrace.booking.failed('$act failed', e, st, fields);
      rethrow;
    }
  }

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) =>
      cachedFetch<List<Reservation>>(
        cache: _cache,
        key: 'resv:$workspaceId:${from.toUtc().toIso8601String()}'
            ':${to.toUtc().toIso8601String()}',
        ttl: const Duration(minutes: 15),
        mode: CacheReadMode.networkFirst,
        fetchRaw: () async {
          // Lazy day-end sweep before reading (#396, the
          // sweep_pending_events pattern): a no-op unless the workspace
          // enabled autoCheckInOut — the RPC checks the flag server-side.
          // Inside fetchRaw on purpose: when the network is down the
          // cache path answers without a doomed extra round-trip. And
          // NEVER fatal — a sweep that fails (function not yet applied,
          // transient hiccup) must not take the reservation read down
          // with it; the next fetch simply tries again.
          try {
            await _client.rpc<dynamic>('sweep_day_end', params: {
              'p_workspace_id': workspaceId,
            });
          } catch (e, st) {
            TraceLogger.instance
                .warn('booking', 'day-end sweep failed', error: e, stackTrace: st);
          }
          return _client
              .from('reservations')
              .select()
              .eq('workspace_id', workspaceId)
              .lt('starts_at', to.toUtc().toIso8601String())
              .gt('ends_at', from.toUtc().toIso8601String())
              .order('starts_at', ascending: true);
        },
        parse: (payload) => [
          for (final row in payload as List)
            _fromRow(Map<String, dynamic>.from(row as Map)),
        ],
      );

  @override
  Future<List<Reservation>> fetchAllForExport(String workspaceId) async {
    final rows = await _client
        .from('reservations')
        .select()
        .eq('workspace_id', workspaceId)
        .order('starts_at', ascending: true);
    return [
      for (final row in rows) _fromRow(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) async {
    // `checkIn` is the field that answers "they booked but were never
    // checked in" (#772) without guessing: it says whether the walk-up
    // was atomic or whether the app only reserved.
    final result = await _traced(
      'reserve',
      {
        'seat': seatId,
        'desk': deskId,
        'office': officeId,
        'level': levelId,
        'from': startsAt.toUtc(),
        'to': endsAt.toUtc(),
        'checkIn': checkIn,
      },
      () => _client.rpc<dynamic>('create_reservation', params: {
        'p_workspace_id': workspaceId,
        'p_seat_id': seatId,
        'p_desk_id': deskId,
        'p_office_id': officeId,
        'p_level_id': levelId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_check_in': checkIn,
      }),
    );
    await _bust();
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
    final result = await _traced(
      'reserve-for',
      {
        'subject': subjectMemberId,
        'seat': seatId,
        'level': levelId,
        'from': startsAt.toUtc(),
        'to': endsAt.toUtc(),
      },
      () => _client.rpc<dynamic>('admin_create_reservation_for', params: {
        'p_workspace_id': workspaceId,
        'p_subject_member_id': subjectMemberId,
        'p_seat_id': seatId,
        'p_level_id': levelId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
      }),
    );
    await _bust();
    return result as String;
  }

  @override
  Future<void> checkIn(String reservationId) async {
    await _traced('check-in', {'reservation': reservationId}, () async {
      await _client.rpc<dynamic>('check_in_reservation', params: {
        'p_reservation_id': reservationId,
      });
    });
    await _bust();
  }

  @override
  Future<KioskIdentity> kioskIdentify({
    required String workspaceId,
    required String badgeToken,
  }) async {
    final result = await _client.rpc<dynamic>('kiosk_identify', params: {
      'p_workspace_id': workspaceId,
      'p_badge_token': badgeToken,
    }) as Map<String, dynamic>;
    // #616: pre-0117 servers answer without the avatar keys — the
    // receipt then simply shows the initial, never an error.
    return (
      name: result['display_name'] as String,
      userId: result['user_id'] as String? ?? '',
      hasAvatar: result['has_avatar'] as bool? ?? false,
    );
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
    await _bust();
    return result['reservation_id'] as String;
  }

  @override
  Future<void> checkOut(String reservationId) async {
    await _traced('check-out', {'reservation': reservationId}, () async {
      await _client.rpc<dynamic>('check_out_reservation', params: {
        'p_reservation_id': reservationId,
      });
    });
    await _bust();
  }

  @override
  Future<void> cancel(String reservationId) async {
    await _traced('cancel', {'reservation': reservationId}, () async {
      await _client.rpc<dynamic>('cancel_reservation', params: {
        'p_reservation_id': reservationId,
      });
    });
    await _bust();
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
    await _bust();
  }

  @override
  Future<SeriesResult> createSeries({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  }) async {
    final result = await _traced(
      'reserve-series',
      {
        'seat': seatId,
        'desk': deskId,
        'office': officeId,
        'level': levelId,
        'from': firstStart.toUtc(),
        'pattern': pattern.name,
        'until': until.toUtc(),
      },
      () => _client.rpc<dynamic>('create_series', params: {
        'p_workspace_id': workspaceId,
        'p_seat_id': seatId,
        'p_desk_id': deskId,
        'p_office_id': officeId,
        'p_level_id': levelId,
        'p_first_start': firstStart.toUtc().toIso8601String(),
        'p_first_end': firstEnd.toUtc().toIso8601String(),
        'p_pattern': pattern.name,
        'p_until': until.toUtc().toIso8601String(),
      }),
    ) as Map<String, dynamic>;
    List<DateTime> dates(String key) => (result[key] as List<dynamic>)
        .map((v) => DateTime.parse(v as String))
        .toList();
    await _bust();
    return SeriesResult(
      seriesId: result['series_id'] as String,
      booked: dates('booked'),
      skipped: dates('skipped'),
    );
  }

  @override
  Future<int> cancelSeries(String seriesId, {DateTime? from}) async {
    final result = await _traced(
      'cancel-series',
      {'series': seriesId, 'from': from?.toUtc()},
      () => _client.rpc<dynamic>('cancel_series', params: {
        'p_series_id': seriesId,
        'p_from': from?.toUtc().toIso8601String(),
      }),
    );
    await _bust();
    return result as int;
  }

  @override
  Future<Reservation?> fetchById(String reservationId) async {
    final row = await _client
        .from('reservations')
        .select()
        .eq('id', reservationId)
        .maybeSingle();
    return row == null ? null : _fromRow(Map<String, dynamic>.from(row));
  }

  Reservation _fromRow(Map<String, dynamic> row) => Reservation(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        seatId: row['seat_id'] as String?,
        deskId: row['desk_id'] as String?,
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
        spaceLabel: row['space_label'] as String?,
      );
}
