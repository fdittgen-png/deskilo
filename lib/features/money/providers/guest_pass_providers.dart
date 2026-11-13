// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the space's guest passes and their sale.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/guest_pass_commands.dart';
import '../data/supabase_guest_pass_repository.dart';
import '../domain/guest_pass.dart';
import 'credit_providers.dart';

// The workspace context the guest passes screen reads, through one door.
export '../../workspace/domain/workspace.dart' show Workspace;
export '../../workspace/providers/workspace_providers.dart'
    show currentWorkspaceProvider, myPermissionsProvider;

part 'guest_pass_providers.g.dart';

@Riverpod(keepAlive: true)
GuestPassRepository guestPassRepository(Ref ref) =>
    SupabaseGuestPassRepository(ref.watch(moneyClientProvider));

/// The passes of [workspaceId], by name.
@riverpod
Future<List<GuestPassOffer>> guestPassOffers(Ref ref, String workspaceId) =>
    ref.watch(guestPassRepositoryProvider).offers(workspaceId);

/// #3614 — the passes sold in [workspaceId], the latest first.
@riverpod
Future<List<GuestPassRecord>> guestPassesSold(Ref ref, String workspaceId) =>
    ref.watch(guestPassRepositoryProvider).passesSold(workspaceId);

/// The places a pass can book in [workspaceId].
@riverpod
Future<List<GuestPassPlace>> guestPassPlaces(Ref ref, String workspaceId) =>
    ref.watch(guestPassRepositoryProvider).places(workspaceId);

/// What the guest passes screen does.
@riverpod
GuestPassCommands guestPassCommands(Ref ref) =>
    GuestPassCommands(ref.watch(guestPassRepositoryProvider));
