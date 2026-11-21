// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the seller's customer quotes.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/active_settings.dart';
import '../application/customer_quote_commands.dart';
import '../data/supabase_customer_quote_repository.dart';
import '../domain/customer_quote.dart';
import '../domain/quote_validity.dart';
import 'credit_providers.dart';

final customerQuoteRepositoryProvider = Provider<CustomerQuoteRepository>(
  (ref) => SupabaseCustomerQuoteRepository(ref.watch(moneyClientProvider)),
);

/// What the issuer does to a quote.
final customerQuoteCommandProvider = Provider<CustomerQuoteCommands>(
  (ref) => CustomerQuoteCommands(ref.watch(customerQuoteRepositoryProvider)),
);

/// The quotes of one workspace. A refusal (no right, switched off, an older
/// host) stays an error the screen words; it is never read as "no quotes".
/// No silent retry: the screen offers its own.
final customerQuotesProvider = FutureProvider.autoDispose
    .family<List<CustomerQuote>, String>(
      (ref, workspaceId) =>
          ref.watch(customerQuoteRepositoryProvider).quotes(workspaceId),
      retry: (_, _) => null,
    );

/// One quote with its revisions, as the server answers it now.
final customerQuoteProvider = FutureProvider.autoDispose
    .family<CustomerQuote, ({String workspaceId, String quoteId})>(
      (ref, key) => ref
          .watch(customerQuoteRepositoryProvider)
          .quote(key.workspaceId, key.quoteId),
      retry: (_, _) => null,
    );

/// #4291 -- how long a new quote stays valid and the longest it may, from the
/// business's own settings (the registry default until it sets them).
final quoteValidityProvider = Provider.autoDispose<QuoteValidity>(
  (ref) => QuoteValidity.fromSettings(ref.watch(activeSettingsProvider)),
);
