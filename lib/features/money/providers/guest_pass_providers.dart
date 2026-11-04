// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the space's guest passes and their sale.
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// The places a pass can book in [workspaceId].
@riverpod
Future<List<GuestPassPlace>> guestPassPlaces(Ref ref, String workspaceId) =>
    ref.watch(guestPassRepositoryProvider).places(workspaceId);
