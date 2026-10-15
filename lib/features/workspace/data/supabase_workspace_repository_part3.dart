// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_workspace_repository.dart';

// #2386 — part 3 of SupabaseWorkspaceRepository, split out of supabase_workspace_repository.dart so no
// file holds the whole class.
extension _SupabaseWorkspaceRepositoryPart3 on SupabaseWorkspaceRepository {

  Future<void> _requestRoleChangeImpl(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    await _client.rpc<dynamic>('request_role_change', params: {
      'p_workspace_id': workspaceId,
      'p_target_member_id': memberId,
      'p_make_admin': makeAdmin,
    });
  }

  Future<String> _setWorkspaceCodeImpl(String workspaceId, String code) async {
    final result = await _client.rpc<dynamic>('set_workspace_code', params: {
      'p_workspace_id': workspaceId,
      'p_code': code,
    });
    return result as String;
  }

  Future<List<int>> _fetchOpenWeekdaysImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    final raw = rules['open_weekdays'] as List<dynamic>?;
    if (raw == null) return const [1, 2, 3, 4, 5];
    return raw.map((e) => (e as num).toInt()).toList();
  }

  Future<void> _setOpenWeekdaysImpl(String workspaceId, List<int> weekdays) =>
      // #1147 — ONE key, merged in the database (0195). The SELECT → Dart
      // merge → UPDATE this replaced put the whole object back from a
      // snapshot, so two admins editing different rules from screens
      // opened at different times undid each other — the #1089 shape.
      _mergeBookingRule(workspaceId, 'open_weekdays', weekdays);

  Future<String?> _fetchDefaultPeriodImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    final wire = rules['default_period'];
    return wire is String && wire.isNotEmpty ? wire : null;
  }

  Future<void> _setDefaultPeriodImpl(String workspaceId, String? wire) =>
      // Merge-preserving, like every other booking rule (#1089).
      _mergeBookingRule(workspaceId, 'default_period', wire ?? '');

  Future<BookingGranularity> _fetchBookingGranularityImpl(
    String workspaceId,
  ) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = row['booking_rules'] as Map<String, dynamic>? ?? const {};
    return BookingGranularity.fromWire(
      rules[BookingRulesKeys.granularity] as String?,
    );
  }

  Future<void> _setBookingGranularityImpl(
    String workspaceId,
    BookingGranularity granularity,
  ) =>
      // #1147 — see setOpenWeekdays.
      _mergeBookingRule(
          workspaceId, BookingRulesKeys.granularity, granularity.wireName);

  Future<WorkHours> _fetchWorkHoursImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    return WorkHours.fromRules(
      row['booking_rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<BookingPolicies> _fetchBookingPoliciesImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    return BookingPolicies.fromRules(
        row['booking_rules'] as Map<String, dynamic>?);
  }

  Future<NewMemberDefaults> _fetchNewMemberDefaultsImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    return NewMemberDefaults.fromRules(
        row['billing_rules'] as Map<String, dynamic>?);
  }

  Future<void> _setNewMemberDefaultsImpl(
    String workspaceId,
    NewMemberDefaults defaults,
  ) async {
    // Keyed, so the merge happens in the database and a sibling billing
    // rule survives (#1089, and 0221's `set_billing_rule`).
    await _client.rpc<dynamic>('set_billing_rule', params: {
      'p_workspace_id': workspaceId,
      'p_key': newMemberDefaultsKey,
      'p_value': defaults.toValue(),
    });
  }

  Future<Map<String, dynamic>> _fetchLexiconImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('lexicon')
        .eq('id', workspaceId)
        .single();
    return row['lexicon'] as Map<String, dynamic>? ?? const {};
  }

  Future<void> _setLexiconTermImpl(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    // Keyed, so the merge happens in the database: a second editor
    // cannot revert the first, and the other locales survive (#1089).
    await _client.rpc<dynamic>('set_workspace_lexicon_term', params: {
      'p_workspace_id': workspaceId,
      'p_locale': locale,
      'p_key': key,
      'p_text': text,
    });
  }

  Future<void> _setWorkspaceEmblemImpl(String workspaceId, Uint8List png) async {
    await _client.storage
        .from('floor-plans')
        .uploadBinary(
          SupabaseWorkspaceRepository.emblemPath(workspaceId),
          png,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
  }

  Future<Uint8List?> _fetchWorkspaceEmblemImpl(String workspaceId) async {
    try {
      return await _client.storage
          .from('floor-plans')
          .download(SupabaseWorkspaceRepository.emblemPath(workspaceId));
    } on StorageException {
      // No object, or not readable by this member: the app renders as it
      // always did. Not a fault worth surfacing (#1289).
      return null;
    }
  }

  Future<void> _clearWorkspaceEmblemImpl(String workspaceId) async {
    await _client.storage
        .from('floor-plans')
        .remove([SupabaseWorkspaceRepository.emblemPath(workspaceId)]);
  }

  Future<Map<String, dynamic>> _setWorkspaceBrandingImpl(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    final dynamic out;
    try {
      out = await _client.rpc<dynamic>('set_workspace_branding', params: {
        'p_workspace_id': workspaceId,
        'p_branding': delta,
      });
    } on PostgrestException catch (e, st) {
      // 0378 — the letters-and-colour pair is unique across workspaces.
      if (e.code == '23505') {
        Error.throwWithStackTrace(const WorkspaceSymbolTaken(), st);
      }
      rethrow;
    }
    return Map<String, dynamic>.from(out as Map? ?? const <String, dynamic>{});
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
    await _client.rpc<dynamic>('set_booking_rule', params: {
      'p_workspace_id': workspaceId,
      'p_key': key,
      'p_value': value,
    });
  }

  Future<void> _setBookingPolicyImpl(
    String workspaceId,
    String key, {
    required bool enabled,
  }) =>
      _mergeBookingRule(workspaceId, key, enabled);

  Future<void> _setLegendProfileImpl(String workspaceId, LegendProfile profile) =>
      _mergeBookingRule(
          workspaceId, BookingPolicies.legendProfileKey, profile.wire);

  Future<void> _setOutsideHoursModeImpl(
    String workspaceId,
    OutsideHoursMode mode,
  ) =>
      _mergeBookingRule(
          workspaceId, BookingPolicies.outsideHoursModeKey, mode.wire);

  Future<void> _setSimultaneousReservationsImpl(String workspaceId, int value) =>
      _mergeBookingRule(workspaceId,
          BookingPolicies.simultaneousReservationsKey, value);

  Future<void> _setBookingLimitImpl(String workspaceId, String key, int value) =>
      _mergeBookingRule(workspaceId, key, value);

  Future<void> _setWorkHoursImpl(String workspaceId, WorkHours hours) async {
    // #1147 — each key merged where the row is; the working hours are a
    // handful of keys and a stale snapshot of the others must not ride
    // along with them.
    for (final entry in hours.toRules().entries) {
      await _mergeBookingRule(workspaceId, entry.key, entry.value as Object);
    }
  }

  Future<String?> _fetchDefaultWorkspaceIdImpl() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('default_workspace_id')
        .eq('id', userId)
        .maybeSingle();
    return row?['default_workspace_id'] as String?;
  }

  Future<void> _setDefaultWorkspaceIdImpl(String? workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('profiles')
        .update({'default_workspace_id': workspaceId}).eq('id', userId);
  }

  Future<List<ClosureDay>> _fetchClosureDaysImpl(String workspaceId) async {
    final rows = await _client
        .from('closure_days')
        .select()
        .eq('workspace_id', workspaceId)
        .order('day', ascending: true);
    return rows.map(_closureDayFromRow).toList();
  }

  Future<HolidayGeneration> _generateClosureDaysImpl(
    String workspaceId, {
    required String country,
    required int year,
    bool apply = false,
  }) async {
    // Definer RPC: the owner gate and the invoiced-month rule are the
    // server's, not this client's (ADR 0020).
    final row = await _client.rpc<dynamic>('generate_closure_days', params: {
      'p_workspace_id': workspaceId,
      'p_country': country,
      'p_year': year,
      'p_apply': apply,
    });
    return holidayGenerationFromJson(
        Map<String, dynamic>.from(row as Map));
  }

  Future<HolidayGeneration> _importClosureDaysImpl(
    String workspaceId, {
    required List<({DateTime day, String name})> days,
    bool apply = false,
  }) async {
    // #2051 — the same rules as generate_closure_days, on the owner's list.
    final row = await _client.rpc<dynamic>('import_closure_days', params: {
      'p_workspace_id': workspaceId,
      'p_days': [
        for (final d in days)
          {'day': d.day.toIso8601String().substring(0, 10), 'name': d.name},
      ],
      'p_apply': apply,
    });
    return holidayGenerationFromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<ClosureDay> _addClosureDayImpl(
    String workspaceId,
    DateTime day,
    String reason,
  ) async {
    final row = await _client
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

  Future<void> _removeClosureDayImpl(String closureDayId) async {
    await _client.from('closure_days').delete().eq('id', closureDayId);
  }

  Future<Workspace> _saveWorkspaceSettingsImpl(
      String workspaceId, WorkspaceSettingsSave save) async {
    try {
      final result = await _client.rpc<dynamic>('save_workspace_settings', params: {
        'p_workspace_id': workspaceId,
        'p_expected_modified': save.expectedModifiedAt?.toUtc().toIso8601String(),
        'p_settings': save.toSettings(),
      });
      return _workspaceFromRow(Map<String, dynamic>.from(
          (result as Map)['workspace'] as Map));
    } on PostgrestException catch (e, st) {
      // trace-exempt: a conflict is rethrown typed with its stack; the screen traces and explains it.
      if (e.code == WorkspaceSettingsConflict.sqlState) {
        Error.throwWithStackTrace(const WorkspaceSettingsConflict(), st);
      }
      rethrow;
    }
  }

  Future<void> _setDeskOpacityImpl(String workspaceId, int opacity) async {
    await _updateWorkspaceRow(workspaceId, {'desk_opacity': opacity});
  }

  Future<void> _resetWorkspaceImpl(String workspaceId) async {
    // SECURITY DEFINER RPC (0039); the owner check + all deletes are atomic
    // server-side.
    await _client.rpc<dynamic>('reset_workspace', params: {
      'p_workspace_id': workspaceId,
    });
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
