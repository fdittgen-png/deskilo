// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the reader's organisations: read on the personal client, as Me
// reads the reader's businesses.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../application/organisation_commands.dart';
import '../data/supabase_organisation_repository.dart';
import '../domain/organisation.dart';
import '../domain/organisation_overview.dart';
import 'workspace_providers.dart';

part 'organisation_providers.g.dart';

@Riverpod(keepAlive: true)
OrganisationRepository organisationRepository(Ref ref) =>
    SupabaseOrganisationRepository(ref.watch(personalClientProvider));

/// Every organisation the reader is a member of a house of.
@riverpod
Future<List<Organisation>> myOrganisations(Ref ref) =>
    ref.watch(organisationRepositoryProvider).myOrganisations();

/// #4007 — the houses of [organisationId] side by side for one month.
@riverpod
Future<OrganisationOverview> organisationOverview(
  Ref ref,
  String organisationId,
  String month,
) => ref
    .watch(organisationRepositoryProvider)
    .overview(organisationId, fromMonth: month, toMonth: month);

/// The owners' commands; a change reads the organisations again.
@Riverpod(keepAlive: true)
OrganisationCommands organisationCommands(Ref ref) => OrganisationCommands(
  ref.watch(organisationRepositoryProvider),
  () {
    ref
      ..invalidate(myOrganisationsProvider)
      // #4005 — a house made is one more business of the person's.
      ..invalidate(myWorkspacesProvider)
      // and a birth record read again once its first task closes.
      ..invalidate(houseBirthProvider)
      // #4008 — a house asked, or a house's welcome changed.
      ..invalidate(joinableHousesProvider)
      ..invalidate(houseWelcomesProvider);
  },
);

/// #4008 — the houses of the reader's organisations they may ask to join.
@riverpod
Future<List<JoinableHouse>> joinableHouses(Ref ref) =>
    ref.watch(organisationRepositoryProvider).joinableHouses();

/// #4008 — whether the house [workspaceId] of [organisationId] welcomes the
/// members of the organisation's other houses at once.
@riverpod
Future<bool> houseWelcomes(
  Ref ref,
  String organisationId,
  String workspaceId,
) => ref
    .watch(organisationRepositoryProvider)
    .welcomesMembers(organisationId, workspaceId);

/// #4005 — the birth record of [workspaceId], if it was made as a house.
@riverpod
Future<HouseBirth?> houseBirth(Ref ref, String workspaceId) =>
    ref.watch(organisationRepositoryProvider).houseBirth(workspaceId);

/// #4005 — the house just made, whose birth record its home shows once.
@Riverpod(keepAlive: true)
class PendingHouseBirth extends _$PendingHouseBirth {
  @override
  String? build() => null;

  /// The house [workspaceId] was just made; null once it was shown.
  void set(String? workspaceId) => state = workspaceId;
}

/// #4005 — the country the house form proposes first: none (the catalogue's
/// first) unless the installation says which. The Demo proposes the one
/// house it can add.
final houseCountryProposalProvider = Provider<String?>((ref) => null);
