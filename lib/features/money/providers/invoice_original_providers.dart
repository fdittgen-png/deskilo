// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — where the stored originals of the invoices are kept, and the
// command that serves an invoice's document from them.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/invoice_originals.dart';
import '../data/supabase_invoice_original_repository.dart';
import '../domain/invoice_original.dart';
import 'credit_providers.dart';
import 'guest_pass_providers.dart' show currentWorkspaceProvider, mayIssueInvoicesProvider;
import 'money_providers.dart';

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

/// #3853 — the invoices of the active business whose original is not kept
/// yet, for someone who may issue invoices (and so keep them); none for
/// anyone else.
@riverpod
Future<List<Invoice>> invoicesWithoutOriginal(Ref ref) async {
  if (!ref.watch(mayIssueInvoicesProvider)) return const [];
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final invoices = await ref.watch(invoicesProvider.future);
  final kept = await ref
      .watch(invoiceOriginalRepositoryProvider)
      .keptIn(workspace.id);
  return [
    for (final i in invoices)
      if (i.keepsOriginal && !kept.contains(i.id)) i,
  ];
}
