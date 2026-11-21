// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/issue_standalone_invoice.dart';
import '../data/supabase_standalone_invoice_commands.dart';
import '../domain/standalone_invoice.dart';
import 'credit_providers.dart' show moneyClientProvider;
import 'money_queries_providers.dart';

/// #4165 -- what a person does to a standalone draft. The Demo overrides it.
final standaloneInvoiceCommandsProvider = Provider<StandaloneInvoiceCommands>(
  (ref) => SupabaseStandaloneInvoiceCommands(ref.watch(moneyClientProvider)),
);

/// #4165 -- issuing once and looking for the answer by the attempt's request id.
final standaloneIssuanceProvider = Provider<StandaloneIssuance>(
  (ref) => StandaloneIssuance(
    ref.watch(standaloneInvoiceCommandsProvider),
    ref.watch(invoiceQueriesProvider),
  ),
);
