// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 W2 -- the booking-rule half of the Supabase workspace repository: the
// open weekdays, granularity, work hours, policies, limits, closure days and
// the default period, as one mixin composed into `SupabaseWorkspaceRepository`
// (the part-file bodies and their `_xxxImpl` forwarders are gone).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/time/work_hours.dart';
import '../domain/booking_granularity.dart';
import '../domain/booking_policies.dart';
import '../domain/booking_rules_repository.dart';
import '../domain/closure_day.dart';
import '../domain/public_holidays.dart';

mixin SupabaseBookingRules implements BookingRulesRepository {
  /// The client of the class this is mixed into.
  SupabaseClient get client;

  @override
  Future<List<int>> fetchOpenWeekdays(String workspaceId) async {
    final row = await client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    final raw = rules['open_weekdays'] as List<dynamic>?;
    if (raw == null) return const [1, 2, 3, 4, 5];
    return raw.map((e) => (e as num).toInt()).toList();
  }

  @override
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) =>
      // #1147 — ONE key, merged in the database (0195). The SELECT → Dart
      // merge → UPDATE this replaced put the whole object back from a
      // snapshot, so two admins editing different rules from screens
      // opened at different times undid each other — the #1089 shape.
      _mergeBookingRule(workspaceId, 'open_weekdays', weekdays);

  @override
  Future<String?> fetchDefaultPeriod(String workspaceId) async {
    final row = await client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    final wire = rules['default_period'];
    return wire is String && wire.isNotEmpty ? wire : null;
  }

  @override
  Future<void> setDefaultPeriod(String workspaceId, String? wire) =>
      // Merge-preserving, like every other booking rule (#1089).
      _mergeBookingRule(workspaceId, 'default_period', wire ?? '');

  @override
  Future<BookingGranularity> fetchBookingGranularity(
    String workspaceId,
  ) async {
    final row = await client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    return BookingGranularity.fromWire(
      rules[BookingRulesKeys.granularity] as String?,
    );
  }

  @override
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  ) =>
      // #1147 — see setOpenWeekdays.
      _mergeBookingRule(
          workspaceId, BookingRulesKeys.granularity, granularity.wireName);

  @override
  Future<WorkHours> fetchWorkHours(String workspaceId) async {
    final row = await client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    return WorkHours.fromRules(
      row['booking_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<BookingPolicies> fetchBookingPolicies(String workspaceId) async {
    final row = await client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    return BookingPolicies.fromRules(
        row['booking_rules'] as Map<String, dynamic>?);
  }

/// THE merge-preserving policy write (#600/#624): one booking_rules
  /// key changes, every other key survives — the same jsonb merge as
  /// setBookingGranularity.
  Future<void> _mergeBookingRule(
    String workspaceId,
    String key,
    Object value,
  ) async {
    // #1089 — the merge happens IN the database. This used to SELECT the
    // jsonb, add one key in Dart and UPDATE the whole object back, so two
    // admins with the Availability screen open each wrote a copy of the
    // row as they had found it and the second silently reverted the
    // first — the shape 0176 removed for feature_flags and left here.
    await client.rpc<dynamic>('set_booking_rule', params: {
      'p_workspace_id': workspaceId,
      'p_key': key,
      'p_value': value,
    });
  }

  @override
  Future<void> setBookingPolicy(
    String workspaceId,
    String key, {
    required bool enabled,
  }) =>
      _mergeBookingRule(workspaceId, key, enabled);

  @override
  Future<void> setLegendProfile(String workspaceId, LegendProfile profile) =>
      _mergeBookingRule(
          workspaceId, BookingPolicies.legendProfileKey, profile.wire);

  @override
  Future<void> setOutsideHoursMode(
    String workspaceId,
    OutsideHoursMode mode,
  ) =>
      _mergeBookingRule(
          workspaceId, BookingPolicies.outsideHoursModeKey, mode.wire);

  @override
  Future<void> setSimultaneousReservations(String workspaceId, int value) =>
      _mergeBookingRule(workspaceId,
          BookingPolicies.simultaneousReservationsKey, value);

  @override
  Future<void> setBookingLimit(String workspaceId, String key, int value) =>
      _mergeBookingRule(workspaceId, key, value);

  @override
  Future<void> setWorkHours(String workspaceId, WorkHours hours) async {
    // #1147 — each key merged where the row is; the working hours are a
    // handful of keys and a stale snapshot of the others must not ride
    // along with them.
    for (final entry in hours.toRules().entries) {
      await _mergeBookingRule(workspaceId, entry.key, entry.value as Object);
    }
  }

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async {
    final rows = await client
        .from('closure_days')
        .select()
        .eq('workspace_id', workspaceId)
        .order('day', ascending: true);
    return rows.map(_closureDayFromRow).toList();
  }

  @override
  Future<HolidayGeneration> generateClosureDays(
    String workspaceId, {
    required String country,
    required int year,
    bool apply = false,
  }) async {
    // Definer RPC: the owner gate and the invoiced-month rule are the
    // server's, not this client's (ADR 0020).
    final row = await client.rpc<dynamic>('generate_closure_days', params: {
      'p_workspace_id': workspaceId,
      'p_country': country,
      'p_year': year,
      'p_apply': apply,
    });
    return holidayGenerationFromJson(
        Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<HolidayGeneration> importClosureDays(
    String workspaceId, {
    required List<({DateTime day, String name})> days,
    bool apply = false,
  }) async {
    // #2051 — the same rules as generate_closure_days, on the owner's list.
    final row = await client.rpc<dynamic>('import_closure_days', params: {
      'p_workspace_id': workspaceId,
      'p_days': [
        for (final d in days)
          {'day': d.day.toIso8601String().substring(0, 10), 'name': d.name},
      ],
      'p_apply': apply,
    });
    return holidayGenerationFromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<ClosureDay> addClosureDay(
    String workspaceId,
    DateTime day,
    String reason,
  ) async {
    final row = await client
        .from('closure_days')
        .insert({
          'workspace_id': workspaceId,
          'day': _isoDate(day),
          'reason': reason,
        })
        .select()
        .single();
    return _closureDayFromRow(row);
  }

  @override
  Future<void> removeClosureDay(String closureDayId) async {
    await client.from('closure_days').delete().eq('id', closureDayId);
  }

/// Postgres `date` wire format for [day]'s date part.
  String _isoDate(DateTime day) => isoDay(day);

ClosureDay _closureDayFromRow(Map<String, dynamic> row) => ClosureDay(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        day: DateTime.parse(row['day'] as String),
        reason: row['reason'] as String? ?? '',
      );
}
