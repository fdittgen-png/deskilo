// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/date_text.dart';
import '../domain/room_level_kind.dart';
import '../domain/room_rental.dart';

/// The rented rooms and their RPCs (0496-0498). Reading checks the right on
/// the server; every write derives actor and rights there.
class SupabaseRoomRentalRepository implements RoomRentalRepository {
  const SupabaseRoomRentalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RoomRentalsOverview> fetchOverview(String workspaceId) async =>
      RoomRentalsOverview.fromJson(
        await _client.rpc<Object?>(
          'room_rentals_v1',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<void> setLevelKind(
    String workspaceId,
    String levelId,
    LevelKind kind,
  ) async {
    await _client.rpc<Object?>(
      'set_level_kind_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_level_id': levelId,
        'p_kind': kind.wire,
      },
    );
  }

  @override
  Future<RoomRental> saveRental(
    String workspaceId,
    RoomRentalCommand command,
  ) async {
    final saved = await _client.rpc<Object?>(
      'save_room_rental_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_office_id': command.officeId,
        'p_supplier_id': command.supplierId,
        'p_available_from': isoDay(command.availableFrom),
        'p_available_until': command.availableUntil == null
            ? null
            : isoDay(command.availableUntil!),
        'p_cost_kind': command.costKind,
        'p_cost_cents': command.costCents,
        'p_period': command.period,
        'p_status': command.status.wire,
        'p_document_id': null,
        'p_revision': command.revision,
        'p_audience_all': command.audienceAll,
      },
    );
    final id = RoomRental.fromJson(saved).id;
    await _client.rpc<Object?>(
      'set_room_rental_audience_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_rental_id': id,
        'p_audience': [for (final a in command.audience) a.toJson()],
      },
    );
    return RoomRental.fromJson(
      await _client.rpc<Object?>(
        'set_room_rental_fees_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_rental_id': id,
          'p_fees': [for (final f in command.fees) f.toJson()],
        },
      ),
    );
  }

  @override
  Future<RoomOffer> fetchOffer(String workspaceId, String officeId) async =>
      RoomOffer.fromJson(
        await _client.rpc<Object?>(
          'room_offer_v1',
          params: {'p_workspace_id': workspaceId, 'p_office_id': officeId},
        ),
      );
}
