// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/room_offer.dart';

/// `room_offer_v1` (0496): the server decides whether the room is open to the
/// member and what it costs them.
class SupabaseRoomOfferRepository implements RoomOfferRepository {
  const SupabaseRoomOfferRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RoomOfferView> fetch(String workspaceId, String officeId) async =>
      RoomOfferView.fromJson(
        await _client.rpc<Object?>(
          'room_offer_v1',
          params: {'p_workspace_id': workspaceId, 'p_office_id': officeId},
        ),
      );
}
