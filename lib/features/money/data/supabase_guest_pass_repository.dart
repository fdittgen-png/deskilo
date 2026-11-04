// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the space's guest passes and their sale, over this server
// (guest_pass_offers under its select policy; save_guest_pass_offer and
// sell_guest_pass, 0672).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/guest_pass.dart';

class SupabaseGuestPassRepository implements GuestPassRepository {
  const SupabaseGuestPassRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuestPassOffer>> offers(String workspaceId) async {
    final rows = await _client
        .from('guest_pass_offers')
        .select()
        .eq('workspace_id', workspaceId)
        .order('name');
    return [for (final r in rows) GuestPassOffer.fromJson(r)];
  }

  @override
  Future<List<GuestPassPlace>> places(String workspaceId) async {
    final rows = await _client
        .from('seats')
        .select('id, name, desks(offices(levels(name)))')
        .eq('workspace_id', workspaceId)
        .order('name');
    String level(Map<String, Object?> r) {
      final desk = JsonReader.orEmpty(r).objectOrAbsent('desks');
      return desk.objectOrAbsent('offices').objectOrAbsent('levels').stringOr('name');
    }

    return [
      for (final r in rows)
        (
          seatId: r['id'] as String,
          label: [level(r), r['name'] as String? ?? ''].where((s) => s.isNotEmpty).join(' · '),
        ),
    ];
  }

  @override
  Future<String> saveOffer(
    String workspaceId, {
    String? id,
    required String name,
    required GuestPassUnit unit,
    required int priceCents,
    String? vatRateId,
    bool active = true,
  }) async =>
      await _client.rpc<Object?>('save_guest_pass_offer', params: {
        'p_workspace_id': workspaceId,
        'p_id': id,
        'p_name': name,
        'p_unit': unit.wire,
        'p_price_cents': priceCents,
        'p_vat_rate_id': vatRateId,
        'p_active': active,
      }) as String;

  @override
  Future<GuestPassSale> sell(
    String workspaceId, {
    required GuestPassDraft draft,
    required Map<String, Object?> guest,
    required String requestId,
  }) async {
    final row = await _client.rpc<Object?>('sell_guest_pass', params: {
      'p_workspace_id': workspaceId,
      'p_offer_id': draft.offer!.id,
      'p_guest': guest,
      'p_seat_id': draft.seatId,
      'p_starts_at': draft.startsAt.toUtc().toIso8601String(),
      'p_ends_at': draft.endsAt.toUtc().toIso8601String(),
      'p_request_id': requestId,
      'p_paid': draft.paid,
      'p_method': draft.method,
      'p_days': draft.days,
    });
    return GuestPassSale.fromJson(Map<String, Object?>.from(row! as Map));
  }
}
