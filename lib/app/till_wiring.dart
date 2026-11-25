// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till talks to the open workspace's server. Composed here, where both features are, so the money feature
// does not import the workspace for it.
import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Consumer;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/backend/auth_secret_store.dart';
import '../core/settings/settings.dart' show SettingScope;
import '../features/money/data/secure_offline_store.dart';
import '../features/money/data/supabase_counter_book.dart';
import '../features/money/data/supabase_counter_offline.dart';
import '../features/money/data/supabase_counter_till.dart';
import '../features/money/data/supabase_till_drawer.dart';
import '../features/money/data/supabase_till_layouts.dart';
import '../features/money/domain/till_drawer.dart';
import '../features/money/providers/counter_book_providers.dart';
import '../features/money/providers/till_drawer_providers.dart';
import '../features/money/providers/till_layout_providers.dart';
import '../features/money/providers/till_providers.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/domain/workspace_permission.dart';
import '../features/workspace/presentation/widgets/settings_editor.dart';
import '../features/workspace/providers/operation_context_providers.dart';
import '../features/workspace/providers/settings_providers.dart';
import '../features/workspace/providers/workspace_providers.dart' show enabledFeaturesSyncProvider, myPermissionsProvider;

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

/// #4373 -- the offline state of a till is kept in the app's secure store, one entry per business.
final Override tillOfflineStoreFromApp = tillOfflineStoreFactoryProvider.overrideWithValue(
  (workspaceId) => SecureOfflineStore(const PlatformAuthSecretStore(), workspaceId: workspaceId),
);

/// #4373 -- the till sells offline when the business runs till sessions and has the offline feature on.
final Override tillOfflineEnabledFromApp = tillOfflineEnabledProvider.overrideWith((ref) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  return features.contains(WorkspaceFeature.counterTillSessions) && features.contains(WorkspaceFeature.counterOfflineCash);
});

/// #4184 -- how the business's counter receipts leave the counter, read from its settings (`counter.document_channel`).
final Override counterDocumentChannelFromApp = counterDocumentChannelProvider.overrideWith((ref, workspaceId) {
  final value = ref.watch(settingsSetProvider(workspaceId)).value?.effective['counter.document_channel'];
  return value is String ? value : 'share';
});

/// #4184 -- the counter's settings are edited in the registry editor, by whoever may change the workspace's settings.
final Override counterSettingsEditorFromApp = counterSettingsEditorProvider.overrideWithValue(
  (workspaceId) => Consumer(
    builder: (context, ref, _) => SettingsEditor(
      key: const Key('counter-readiness-settings'),
      scope: SettingScope.workspace,
      workspaceId: workspaceId,
      keyPrefix: 'counter.',
      canEdit: ref.watch(myPermissionsProvider).contains(WorkspacePermission.workspaceSettings),
    ),
  ),
);

/// #4185 -- the counter's book (its receipts, corrections, refunds, returns and card answers) on the same server.
/// #4448 -- the till layouts on the same server.
final Override tillLayoutPortFromApp = tillLayoutPortProvider.overrideWith((ref) => SupabaseTillLayouts(ref.watch(selectedWorkspaceClientProvider)));

final Override counterBookPortFromApp = counterBookPortProvider.overrideWith(
  (ref) => SupabaseCounterBook(ref.watch(selectedWorkspaceClientProvider)),
);
