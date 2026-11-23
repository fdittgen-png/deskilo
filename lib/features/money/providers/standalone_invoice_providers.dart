// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../application/issue_standalone_invoice.dart';
import '../data/supabase_standalone_invoice_commands.dart';
import '../domain/standalone_invoice.dart';
import 'credit_providers.dart' show moneyClientProvider;
import 'money_providers.dart' show dunningRulesProvider;
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

/// #4426 -- the days a new invoice's due date is offered after its service date: the workspace's payment term, the
/// setting `dunning.first_after_days` the server freezes a standalone invoice's maturity from ("the workspace payment
/// term of N days"), so the preview and the issued invoice agree. While the setting is not read, or the workspace has not
/// set it, the registry's own default stands: the number the server falls back to.
final invoiceDueDaysProvider = Provider<int>(
  (ref) => ref.watch(dunningRulesProvider).value?.firstAfterDays ?? SettingDefaults.dunningFirstAfterDays,
);
