// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer statement's reader (overridable in tests and the
// demonstration, which answers it from its own rows).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_customer_statement.dart';
import '../domain/customer_statement.dart';
import 'credit_providers.dart';

/// #3876 — the day a statement is read and printed for: the BUSINESS's
/// calendar day of [now], never the device's. The customer page and both
/// statement prints take it here, so a figure and the document that prints
/// it always speak of the same day.
DateTime statementDayOf(InvoicingBusiness business, DateTime now) =>
    business.dayOf(now);

final customerStatementReaderProvider = Provider<CustomerStatementReader>(
  (ref) => SupabaseCustomerStatementReader(ref.watch(moneyClientProvider)),
);
