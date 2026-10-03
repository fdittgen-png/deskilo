// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../application/guest_visit_actions.dart';
import '../data/supabase_guest_participation_repository.dart';
import '../domain/guest_participation.dart';

part 'visits_providers.g.dart';

/// #1835 — the guest's own visits, over this server's definer functions.
@Riverpod(keepAlive: true)
GuestParticipationRepository guestParticipationRepository(Ref ref) =>
    SupabaseGuestParticipationRepository(Supabase.instance.client);

/// The guest's actions on their own visits.
@riverpod
GuestVisitActions guestVisitActions(Ref ref) =>
    GuestVisitActions(ref.watch(guestParticipationRepositoryProvider));

/// My visits, newest first. Nobody signed in holds none.
@riverpod
Future<List<GuestParticipation>> myGuestVisits(Ref ref) {
  if (ref.watch(authStateProvider).value == null) {
    return Future.value(const <GuestParticipation>[]);
  }
  return ref.watch(guestParticipationRepositoryProvider).myVisits();
}
