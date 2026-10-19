// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2568 — the rooms the space rents.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/room_rental_commands.dart';
import '../data/supabase_room_rental_repository.dart';
import '../domain/room_rental.dart';
import 'credit_providers.dart';

final roomRentalRepositoryProvider = Provider<RoomRentalRepository>(
  (ref) => SupabaseRoomRentalRepository(ref.watch(moneyClientProvider)),
);

/// Saving a rental and marking a level external.
final roomRentalCommandProvider = Provider<RoomRentalCommands>(
  (ref) => RoomRentalCommands(ref.watch(roomRentalRepositoryProvider)),
);

/// The rentals, levels and rentable rooms of one workspace.
final roomRentalsProvider = FutureProvider.autoDispose
    .family<RoomRentalsOverview, String>(
      (ref, workspaceId) =>
          ref.watch(roomRentalRepositoryProvider).fetchOverview(workspaceId),
    );
