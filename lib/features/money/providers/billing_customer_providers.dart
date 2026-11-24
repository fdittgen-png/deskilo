// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the seller's billing customers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/billing_access_commands.dart';
import '../application/billing_customer_commands.dart';
import '../data/supabase_billing_access_repository.dart';
import '../data/supabase_billing_customer_repository.dart';
import '../domain/billing_access.dart';
import '../domain/billing_customer.dart';
import 'credit_providers.dart';

final billingCustomerRepositoryProvider = Provider<BillingCustomerRepository>(
  (ref) => SupabaseBillingCustomerRepository(ref.watch(moneyClientProvider)),
);

/// Creating and editing, behind the pure rules.
final billingCustomerCommandProvider = Provider<BillingCustomerCommands>(
  (ref) => BillingCustomerCommands(ref.watch(billingCustomerRepositoryProvider)),
);

/// The billing customers of one workspace. A refusal (no right, an older host)
/// stays an error the screen words; it is never read as "no customers".
///
/// No silent retry: the screen offers its own, so a refusal or a lost
/// connection is shown at once and an empty list is never guessed.
final billingCustomersProvider = FutureProvider.autoDispose
    .family<List<BillingParty>, String>(
      (ref, workspaceId) =>
          ref.watch(billingCustomerRepositoryProvider).fetch(workspaceId),
      retry: (_, _) => null,
    );

/// #4164 B2 -- the billing-access grants (the seller's invitation, the
/// account's preview and acceptance).
final billingAccessRepositoryProvider = Provider<BillingAccessRepository>(
  (ref) => SupabaseBillingAccessRepository(ref.watch(moneyClientProvider)),
);

final billingAccessCommandProvider = Provider<BillingAccessCommands>(
  (ref) => BillingAccessCommands(ref.watch(billingAccessRepositoryProvider)),
);
