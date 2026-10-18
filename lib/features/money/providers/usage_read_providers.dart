// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2590 — the usage face reads a month without writing it, and records the
// month on request.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/usage_commands.dart';
import '../data/supabase_usage_preparation.dart';
import '../domain/usage_record.dart';
import 'credit_providers.dart';
import 'usage_providers.dart';

final usagePreparationProvider = Provider<UsagePreparation>(
  (ref) => SupabaseUsagePreparation(ref.watch(moneyClientProvider)),
);

final usageCommandProvider = Provider<UsageCommands>(
  (ref) => UsageCommands(ref.watch(usagePreparationProvider)),
);

/// A usage month changed (a record made, corrected or removed): reread it.
void invalidateUsage(WidgetRef ref) => ref.invalidate(usageReadProvider);
