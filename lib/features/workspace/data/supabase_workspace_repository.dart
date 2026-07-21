// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/booking_granularity.dart';
import '../domain/closure_day.dart';
import '../domain/member.dart';
import '../domain/member_badge.dart';
import '../domain/overage_policy.dart';
import '../domain/payment_instructions.dart';
import '../domain/workspace.dart';
import '../domain/workspace_repository.dart';

class SupabaseWorkspaceRepository implements WorkspaceRepository {
  SupabaseWorkspaceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    final rows = await _client.from('workspaces').select();
    return rows.map(_workspaceFromRow).toList();
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    final result = await _client.rpc<dynamic>('create_workspace', params: {
      'p_name': name,
      'p_country_code': countryCode,
      'p_currency_code': currencyCode,
      'p_timezone': timezone,
    });
    return result as String;
  }

  @override
  Future<String> joinWorkspace(String inviteCode) async {
    final result = await _client.rpc<dynamic>('join_workspace', params: {
      'p_invite_code': inviteCode,
    });
    return result as String;
  }

  @override
  Future<String?> adminInviteCode(String workspaceId) async {
    // Owner-only RLS (0030): non-owners simply get no row back.
    final row = await _client
        .from('workspace_admin_invites')
        .select('code')
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    return row?['code'] as String?;
  }

  @override
  Future<void> updateWorkspaceLocale(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    // Direct row update — workspaces_update RLS restricts it to owners,
    // and the 0001 column checks re-validate the ISO shapes (#153).
    await _client.from('workspaces').update({
      'country_code': countryCode.toUpperCase(),
      'currency_code': currencyCode.toUpperCase(),
      'timezone': timezone,
    }).eq('id', workspaceId);
  }

  @override
  Future<void> setPaymentInstructions(
    String workspaceId,
    PaymentInstructions instructions,
  ) async {
    // Wholesale jsonb replace, like feature_flags (#155): the settings
    // form always writes the full three-field blob.
    await _client.from('workspaces').update(
        {'payment_instructions': instructions.toDb()}).eq('id', workspaceId);
  }

  @override
  Future<void> setWhatsappGroup(String workspaceId, String link) async {
    // Direct row update like setPaymentInstructions — workspaces_update
    // RLS restricts it to owners, and the 0029 column check re-validates
    // the chat.whatsapp.com prefix.
    await _client
        .from('workspaces')
        .update({'whatsapp_group': link.trim()}).eq('id', workspaceId);
  }

  @override
  Future<void> setInvitationTemplate(String workspaceId, String template) async {
    // Same shape as setWhatsappGroup — owner-only RLS, 0049 length check.
    await _client
        .from('workspaces')
        .update({'invitation_template': template.trim()}).eq('id', workspaceId);
  }

  @override
  Future<Member?> fetchMyMember(String workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _memberFromRow(row);
  }

  @override
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async {
    // members ↔ profiles share auth.users ids but carry no direct FK, so
    // PostgREST cannot embed — two queries, joined client-side.
    final memberRows = await _client
        .from('members')
        .select('id, user_id')
        .eq('workspace_id', workspaceId);
    final userIds =
        memberRows.map((r) => r['user_id'] as String).toSet().toList();
    if (userIds.isEmpty) return const {};
    final profileRows = await _client
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final nameByUser = {
      for (final r in profileRows)
        r['id'] as String: r['display_name'] as String,
    };
    return {
      for (final r in memberRows)
        r['id'] as String: nameByUser[r['user_id'] as String] ?? '',
    };
  }

  Workspace _workspaceFromRow(Map<String, dynamic> row) => Workspace(
        id: row['id'] as String,
        name: row['name'] as String,
        countryCode: row['country_code'] as String,
        currencyCode: row['currency_code'] as String,
        timezone: row['timezone'] as String,
        inviteCode: row['invite_code'] as String,
        featureFlags:
            row['feature_flags'] as Map<String, dynamic>? ?? const {},
        paymentInstructions:
            row['payment_instructions'] as Map<String, dynamic>? ?? const {},
        whatsappGroup: row['whatsapp_group'] as String? ?? '',
        deskOpacity: (row['desk_opacity'] as num?)?.toInt() ?? 100,
        invitationTemplate: row['invitation_template'] as String? ?? '',
      );

  @override
  Future<void> setFeatureFlags(
    String workspaceId,
    Map<String, bool> flags,
  ) async {
    // The whole jsonb is replaced (unlike booking_rules there are no
    // foreign keys inside it): the Features screen always writes the
    // full current map.
    await _client
        .from('workspaces')
        .update({'feature_flags': flags}).eq('id', workspaceId);
  }

  @override
  Future<List<Member>> fetchMembers(String workspaceId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true);
    return rows.map(_memberFromRow).toList();
  }

  @override
  Future<void> updateMemberSubscription(String memberId, int pct) async {
    await _client
        .from('members')
        .update({'subscription_pct': pct}).eq('id', memberId);
  }

  @override
  Future<void> updateMemberOveragePolicy(
    String memberId,
    OveragePolicy policy,
  ) async {
    await _client
        .from('members')
        .update({'overage_policy': policy.name}).eq('id', memberId);
  }

  @override
  Future<void> setMemberReservationLimit(String memberId, int? limit) async {
    await _client.rpc<dynamic>('set_member_reservation_limit', params: {
      'p_member_id': memberId,
      'p_limit': limit,
    });
  }

  @override
  Future<void> setMemberLevelPermission(
    String memberId, {
    required bool allowed,
  }) async {
    await _client.rpc<dynamic>('set_member_level_permission', params: {
      'p_member_id': memberId,
      'p_allowed': allowed,
    });
  }

  @override
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) async {
    await _client.rpc<dynamic>('set_member_kiosk', params: {
      'p_member_id': memberId,
      'p_is_kiosk': isKiosk,
    });
  }

  @override
  Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) async {
    final rows = await _client
        .from('member_badges')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return rows.map(MemberBadge.fromRow).toList();
  }

  @override
  Future<IssuedBadge> issueMemberBadge(
    String workspaceId,
    String memberId, {
    String label = '',
  }) async {
    final result = await _client.rpc<dynamic>('issue_member_badge', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_label': label,
    }) as Map<String, dynamic>;
    return (
      badgeId: result['badge_id'] as String,
      token: result['token'] as String,
    );
  }

  @override
  Future<void> registerNfcBadge(
    String workspaceId,
    String memberId, {
    required String uid,
    String label = '',
  }) async {
    await _client.rpc<dynamic>('register_nfc_badge', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_uid': uid,
      'p_label': label,
    });
  }

  @override
  Future<void> revokeMemberBadge(String badgeId) async {
    await _client.rpc<dynamic>('revoke_member_badge', params: {
      'p_badge_id': badgeId,
    });
  }

  @override
  Future<void> updateMemberStatus(String memberId, MemberStatus status) async {
    await _client
        .from('members')
        .update({'status': status.name}).eq('id', memberId);
  }

  @override
  Future<List<Member>> fetchMyMembers() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows =
        await _client.from('members').select().eq('user_id', userId);
    return rows.map(_memberFromRow).toList();
  }

  @override
  Future<void> requestRoleChange(
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

  @override
  Future<String> setWorkspaceCode(String workspaceId, String code) async {
    final result = await _client.rpc<dynamic>('set_workspace_code', params: {
      'p_workspace_id': workspaceId,
      'p_code': code,
    });
    return result as String;
  }

  @override
  Future<List<int>> fetchOpenWeekdays(String workspaceId) async {
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

  @override
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) async {
    // booking_rules is one jsonb column; merge client-side so the other
    // keys (horizon, durations, …) survive the write.
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = <String, dynamic>{
      ...?row['booking_rules'] as Map<String, dynamic>?,
      'open_weekdays': weekdays,
    };
    await _client
        .from('workspaces')
        .update({'booking_rules': rules}).eq('id', workspaceId);
  }

  @override
  Future<BookingGranularity> fetchBookingGranularity(
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

  @override
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  ) async {
    // booking_rules is one jsonb column; merge client-side so the other
    // keys (open_weekdays, horizon, durations, …) survive the write.
    final row = await _client
        .from('workspaces')
        .select('booking_rules')
        .eq('id', workspaceId)
        .single();
    final rules = <String, dynamic>{
      ...?row['booking_rules'] as Map<String, dynamic>?,
      BookingRulesKeys.granularity: granularity.wireName,
    };
    await _client
        .from('workspaces')
        .update({'booking_rules': rules}).eq('id', workspaceId);
  }

  @override
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId) async {
    final rows = await _client
        .from('closure_days')
        .select()
        .eq('workspace_id', workspaceId)
        .order('day', ascending: true);
    return rows.map(_closureDayFromRow).toList();
  }

  @override
  Future<ClosureDay> addClosureDay(
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

  @override
  Future<void> removeClosureDay(String closureDayId) async {
    await _client.from('closure_days').delete().eq('id', closureDayId);
  }

  @override
  Future<void> setDeskOpacity(String workspaceId, int opacity) async {
    await _client
        .from('workspaces')
        .update({'desk_opacity': opacity}).eq('id', workspaceId);
  }

  @override
  Future<void> resetWorkspace(String workspaceId) async {
    // SECURITY DEFINER RPC (0039); the owner check + all deletes are atomic
    // server-side.
    await _client.rpc<dynamic>('reset_workspace', params: {
      'p_workspace_id': workspaceId,
    });
  }

  /// Postgres `date` wire format for [day]'s date part.
  String _isoDate(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  ClosureDay _closureDayFromRow(Map<String, dynamic> row) => ClosureDay(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        day: DateTime.parse(row['day'] as String),
        reason: row['reason'] as String? ?? '',
      );

  Member _memberFromRow(Map<String, dynamic> row) => Member(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        isAdmin: row['is_admin'] as bool,
        isOwner: row['is_owner'] as bool,
        status: MemberStatus.values.byName(row['status'] as String),
        subscriptionPct: row['subscription_pct'] as int? ?? 100,
        overagePolicy:
            OveragePolicy.fromName(row['overage_policy'] as String?),
        isKiosk: row['is_kiosk'] as bool? ?? false,
        maxActiveReservations: row['max_active_reservations'] as int?,
        canReserveLevel: row['can_reserve_level'] as bool? ?? false,
      );
}
