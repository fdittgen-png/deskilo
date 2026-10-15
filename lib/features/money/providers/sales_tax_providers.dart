// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the sales-tax summary of a period.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/sales_tax_commands.dart';
import '../data/supabase_sales_tax_repository.dart';
import '../domain/sales_tax_repository.dart';
import '../domain/tax_exemption_certificate.dart';

part 'sales_tax_providers.g.dart';

@Riverpod(keepAlive: true)
SalesTaxRepository salesTaxRepository(Ref ref) =>
    SupabaseSalesTaxRepository(Supabase.instance.client);

@riverpod
SalesTaxCommands salesTaxCommands(Ref ref) =>
    SalesTaxCommands(ref.watch(salesTaxRepositoryProvider));

/// The exemption certificates of one customer, the newest first.
@riverpod
Future<List<TaxExemptionCertificate>> memberTaxCertificates(
  Ref ref,
  String memberId,
) => ref.watch(salesTaxRepositoryProvider).fetchCertificates(memberId);
