// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till talks to the open workspace's server. Composed here, where both features are, so the money feature
// does not import the workspace for it.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/money/data/supabase_counter_offline.dart';
import '../features/money/data/supabase_counter_till.dart';
import '../features/money/providers/till_providers.dart';
import '../features/workspace/providers/operation_context_providers.dart';

/// Puts the live till in a scope's overrides (main.dart).
final Override tillPortFromApp = tillPortProvider.overrideWith(
  (ref) => SupabaseCounterTill(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4373 -- the offline sales go to the same server.
final Override tillOfflinePortFromApp = tillOfflinePortProvider.overrideWith(
  (ref) => SupabaseCounterOffline(ref.watch(selectedWorkspaceClientProvider)),
);
