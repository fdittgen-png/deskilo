// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments behind the collected figure, one page at a time.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_recorded_payments_repository.dart';
import '../domain/recorded_payments.dart';
import 'credit_providers.dart';

final recordedPaymentsRepositoryProvider = Provider<RecordedPaymentsRepository>(
  (ref) => SupabaseRecordedPaymentsRepository(ref.watch(moneyClientProvider)),
);
