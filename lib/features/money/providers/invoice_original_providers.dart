// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — where the stored originals of the invoices are kept.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/supabase_invoice_original_repository.dart';
import '../domain/invoice_original.dart';
import 'credit_providers.dart';

part 'invoice_original_providers.g.dart';

@Riverpod(keepAlive: true)
InvoiceOriginalRepository invoiceOriginalRepository(Ref ref) =>
    SupabaseInvoiceOriginalRepository(ref.watch(moneyClientProvider));
