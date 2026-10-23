// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2863 — looking a supplier up in a company registry.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/lookup_company.dart';
import '../data/supabase_company_lookup_repository.dart';
import '../domain/company_lookup.dart';
import 'credit_providers.dart';

part 'company_lookup_providers.g.dart';

@Riverpod(keepAlive: true)
CompanyLookupRepository companyLookupRepository(Ref ref) =>
    SupabaseCompanyLookupRepository(ref.watch(moneyClientProvider));

/// Asking a registry now (the decision the supplier form asks for).
@riverpod
LookupCompany lookupCompany(Ref ref) =>
    LookupCompany(ref.watch(companyLookupRepositoryProvider));
