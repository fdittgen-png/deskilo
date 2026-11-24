// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till talks to the open workspace's server. Composed here, where both features are, so the money feature
// does not import the workspace for it.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/money/data/supabase_counter_offline.dart';
import '../features/money/data/supabase_counter_till.dart';
import '../features/money/data/supabase_till_drawer.dart';
import '../features/money/domain/till_drawer.dart';
import '../features/money/providers/till_drawer_providers.dart';
import '../features/money/providers/till_providers.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/operation_context_providers.dart';
import '../features/workspace/providers/settings_providers.dart';
import '../features/workspace/providers/workspace_providers.dart' show enabledFeaturesSyncProvider;

/// Puts the live till in a scope's overrides (main.dart).
final Override tillPortFromApp = tillPortProvider.overrideWith(
  (ref) => SupabaseCounterTill(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4367 -- the live cash drawer of the till, in the same scope.
final Override tillDrawerPortFromApp = tillDrawerPortProvider.overrideWith(
  (ref) => SupabaseTillDrawer(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4373 -- the offline sales go to the same server.
final Override tillOfflinePortFromApp = tillOfflinePortProvider.overrideWith(
  (ref) => SupabaseCounterOffline(ref.watch(selectedWorkspaceClientProvider)),
);

/// #4367 -- the business runs till sessions when its feature is on.
final Override tillSessionsFromApp = tillSessionsEnabledProvider.overrideWith(
  (ref) => ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.counterTillSessions),
);

/// #4367 -- how this business counts its drawer, read from its settings (the registry default stands where it set nothing).
final Override drawerSettingsFromApp = drawerSettingsProvider.overrideWith((ref) async {
  final settings = await ref.watch(currentSettingsProvider.future);
  return DrawerSettings(
    blindCount: settings.read<bool>('counter.blind_count'),
    byDenomination: settings.read<bool>('counter.count_by_denomination'),
    reasons: DrawerSettings.reasonsOf(settings.read<String>('counter.cash_reasons')),
    paidOutLimitMinor: settings.read<int>('counter.paid_out_limit_minor'),
  );
});
