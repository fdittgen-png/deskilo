// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer statement's reader (overridable in tests and the
// demonstration, which computes it from its own rows by the page's rules).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_customer_statement.dart';
import '../domain/customer_statement.dart';
import 'credit_providers.dart';

final customerStatementReaderProvider = Provider<CustomerStatementReader>(
  (ref) => SupabaseCustomerStatementReader(ref.watch(moneyClientProvider)),
);
