// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — invoices by e-mail: the server's side (overridable in tests and
// the demonstration, which sends no e-mail), its command, and what the
// invoice page shows of it.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/invoice_mail_commands.dart';
import '../data/supabase_invoice_mail.dart';
import '../domain/invoice_mail.dart';
import 'credit_providers.dart';

final invoiceMailProvider = Provider<InvoiceMail>(
  (ref) => SupabaseInvoiceMail(ref.watch(moneyClientProvider)),
);

final invoiceMailCommandsProvider = Provider<InvoiceMailCommands>(
  (ref) => InvoiceMailCommands(ref.watch(invoiceMailProvider)),
);

/// The invoice page's e-mail state: its customer's reach and every attempt,
/// read from the server's rows (0730).
final invoiceMailViewProvider = FutureProvider.autoDispose
    .family<InvoiceMailView, ({String workspaceId, String invoiceId})>(
      (ref, key) => ref
          .watch(invoiceMailCommandsProvider)
          .view(key.workspaceId, key.invoiceId),
    );
