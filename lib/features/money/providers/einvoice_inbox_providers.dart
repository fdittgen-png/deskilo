// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the supplier e-invoice inbox.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/einvoice_inbox.dart';
import '../data/supabase_einvoice_inbox_repository.dart';
import '../domain/einvoice_inbox.dart';
import 'credit_providers.dart';

final eInvoiceInboxRepositoryProvider = Provider<EInvoiceInboxRepository>(
  (ref) => SupabaseEInvoiceInboxRepository(ref.watch(moneyClientProvider)),
);

/// Receiving, matching and rejecting.
final eInvoiceInboxCommandProvider = Provider<EInvoiceInbox>(
  (ref) => EInvoiceInbox(ref.watch(eInvoiceInboxRepositoryProvider)),
);

/// What is in the inbox of one workspace.
final eInvoiceInboxProvider = FutureProvider.autoDispose
    .family<List<InboxDocument>, String>(
      (ref, workspaceId) =>
          ref.watch(eInvoiceInboxRepositoryProvider).fetchInbox(workspaceId),
    );
