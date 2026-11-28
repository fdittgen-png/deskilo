// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../application/issue_standalone_invoice.dart';
import '../data/supabase_invoice_goods_catalogue.dart';
import '../data/supabase_invoice_service_catalogue.dart';
import '../data/supabase_standalone_invoice_commands.dart';
import '../domain/invoice_goods.dart';
import '../domain/invoice_services.dart';
import '../domain/standalone_invoice.dart';
import 'credit_providers.dart' show moneyClientProvider;
import 'money_providers.dart' show dunningRulesProvider;
import 'money_queries_providers.dart';

/// #4165 -- what a person does to a standalone draft. The Demo overrides it.
final standaloneInvoiceCommandsProvider = Provider<StandaloneInvoiceCommands>(
  (ref) => SupabaseStandaloneInvoiceCommands(ref.watch(moneyClientProvider)),
);

/// #4433 -- the items a business keeps in stock, for a goods line. The Demo overrides it.
final invoiceGoodsCatalogueProvider = Provider<InvoiceGoodsCatalogue>(
  (ref) => SupabaseInvoiceGoodsCatalogue(ref.watch(moneyClientProvider)),
);

/// #4433 -- the items a goods line may sell in a business, read once per composer.
final invoiceGoodsItemsProvider = FutureProvider.autoDispose.family<List<InvoiceGoodsItem>, String>(
  (ref, workspaceId) => ref.watch(invoiceGoodsCatalogueProvider).items(workspaceId),
  retry: (_, _) => null,
);

/// #4510 -- the services of the catalogue a quote or an invoice line may be picked from. The Demo overrides it.
final invoiceServiceCatalogueProvider = Provider<InvoiceServiceCatalogue>(
  (ref) => SupabaseInvoiceServiceCatalogue(ref.watch(moneyClientProvider)),
);

/// #4510 -- the services a line may be picked from in a business, read once per composer.
final invoiceServicesProvider = FutureProvider.autoDispose.family<List<InvoiceService>, String>(
  (ref, workspaceId) => ref.watch(invoiceServiceCatalogueProvider).services(workspaceId),
  retry: (_, _) => null,
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
/// set it, the registry's own default stands: the number the server falls back to. The value is read from the rules the
/// app holds (the settings snapshot when it carries one); a platform-scope override the snapshot does not carry is not seen
/// here, so the offered date can differ from the server's until the person sets one (recorded on #4426).
final invoiceDueDaysProvider = Provider<int>(
  (ref) => ref.watch(dunningRulesProvider).value?.firstAfterDays ?? SettingDefaults.dunningFirstAfterDays,
);
