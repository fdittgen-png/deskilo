// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the reader's organisations: read on the personal client, as Me
// reads the reader's businesses.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../application/organisation_commands.dart';
import '../data/supabase_organisation_repository.dart';
import '../domain/organisation.dart';
import '../domain/organisation_overview.dart';

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
  () => ref.invalidate(myOrganisationsProvider),
);
