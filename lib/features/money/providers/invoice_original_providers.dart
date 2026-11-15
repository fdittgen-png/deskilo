// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — where the stored originals of the invoices are kept, and the
// command that serves an invoice's document from them.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/invoice_originals.dart';
import '../data/supabase_invoice_original_repository.dart';
import '../domain/invoice_original.dart';
import 'credit_providers.dart';
import 'guest_pass_providers.dart' show mayIssueInvoicesProvider;

part 'invoice_original_providers.g.dart';

@Riverpod(keepAlive: true)
InvoiceOriginalRepository invoiceOriginalRepository(Ref ref) =>
    SupabaseInvoiceOriginalRepository(ref.watch(moneyClientProvider));

/// The document of an invoice, from its stored original.
@riverpod
InvoiceOriginals invoiceOriginals(Ref ref) => InvoiceOriginals(
  ref.watch(invoiceOriginalRepositoryProvider),
  mayIssue: ref.watch(mayIssueInvoicesProvider),
);

/// #3853 — the record of the stored original of the invoice [invoiceId] of
/// [workspaceId], or null when none is kept yet.
@riverpod
Future<InvoiceOriginal?> invoiceOriginal(
  Ref ref,
  String workspaceId,
  String invoiceId,
) => ref
    .watch(invoiceOriginalRepositoryProvider)
    .originalOf(workspaceId, invoiceId);
