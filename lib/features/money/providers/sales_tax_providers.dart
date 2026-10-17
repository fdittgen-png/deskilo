// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the sales-tax summary of a period.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/sales_tax_commands.dart';
import '../data/supabase_sales_tax_repository.dart';
import '../domain/sales_tax_repository.dart';
import '../domain/tax_exemption_certificate.dart';
import 'credit_providers.dart';

part 'sales_tax_providers.g.dart';

@Riverpod(keepAlive: true)
SalesTaxRepository salesTaxRepository(Ref ref) =>
    SupabaseSalesTaxRepository(ref.watch(moneyClientProvider));

@riverpod
SalesTaxCommands salesTaxCommands(Ref ref) =>
    SalesTaxCommands(ref.watch(salesTaxRepositoryProvider));

/// The exemption certificates of one customer, the newest first.
@riverpod
Future<List<TaxExemptionCertificate>> memberTaxCertificates(
  Ref ref,
  String memberId,
) => ref.watch(salesTaxRepositoryProvider).fetchCertificates(memberId);
