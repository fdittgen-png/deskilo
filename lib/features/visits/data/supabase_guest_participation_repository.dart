// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/guest_participation.dart';

/// #1835 — the guest's own visits over this server's definer functions
/// (0351). The server projects; nothing reads the table.
class SupabaseGuestParticipationRepository
    implements GuestParticipationRepository {
  const SupabaseGuestParticipationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuestParticipation>> myVisits() async =>
      GuestParticipation.listFromJson(
        await _client.rpc<Object?>('my_guest_participations'),
      );

  @override
  Future<GuestVisitCancelOutcome> cancel(String visitId) async {
    final r = await _client.rpc<Object?>(
      'cancel_my_guest_visit',
      params: {'p_id': visitId},
    );
    return switch (r is Map ? r['status'] : null) {
      'cancelled' => GuestVisitCancelOutcome.cancelled,
      'unchanged' => GuestVisitCancelOutcome.unchanged,
      _ => GuestVisitCancelOutcome.refused,
    };
  }
}
