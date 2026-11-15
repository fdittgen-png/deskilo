// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the reader's organisations: read on the personal client, as Me
// reads the reader's businesses.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../data/supabase_organisation_repository.dart';
import '../domain/organisation.dart';

part 'organisation_providers.g.dart';

@Riverpod(keepAlive: true)
OrganisationRepository organisationRepository(Ref ref) =>
    SupabaseOrganisationRepository(ref.watch(personalClientProvider));

/// Every organisation the reader is a member of a house of.
@riverpod
Future<List<Organisation>> myOrganisations(Ref ref) =>
    ref.watch(organisationRepositoryProvider).myOrganisations();
