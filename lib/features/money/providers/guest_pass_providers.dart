// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the space's guest passes and their sale.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../plan/providers/floor_plan_providers.dart';
import '../data/supabase_guest_pass_repository.dart';
import '../domain/guest_pass.dart';
import 'credit_providers.dart';

part 'guest_pass_providers.g.dart';

@Riverpod(keepAlive: true)
GuestPassRepository guestPassRepository(Ref ref) =>
    SupabaseGuestPassRepository(ref.watch(moneyClientProvider));

/// The passes of [workspaceId], by name.
@riverpod
Future<List<GuestPassOffer>> guestPassOffers(Ref ref, String workspaceId) =>
    ref.watch(guestPassRepositoryProvider).offers(workspaceId);

/// A place a pass can book, named the way the desk reads it.
typedef GuestPassPlace = ({String seatId, String label});

/// Every seat of the active space, level by level (#3308): the places a
/// pass can book. The server checks the place is free and the window open.
@riverpod
Future<List<GuestPassPlace>> guestPassPlaces(Ref ref) async {
  final repository = ref.watch(floorPlanRepositoryProvider);
  final levels = await ref.watch(levelsProvider.future);
  return [
    for (final level in levels)
      for (final seat in (await repository.fetchPlan(level.id)).seats)
        (seatId: seat.id, label: '${level.name} · ${seat.name}'),
  ];
}
