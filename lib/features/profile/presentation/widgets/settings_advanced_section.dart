// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/push/push_status_tile.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/widgets/environment_tile.dart';
import '../../../workspace/application/set_workspace_dev_mode.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'backend_settings_tile.dart';
import 'settings_section_header.dart';

/// #1307 — the Advanced section: which backend this device talks to,
/// the push pipeline, the environment, sites, number sequences and
/// developer mode.
///
/// Extracted so Settings can be reorganized by ownership at all:
/// `settings_screen.dart` sat at exactly its length cap, which meant
/// nothing could be added before something left. The tiles are
/// unchanged — only the list is cut, the same way #1154 cut About.
List<Widget> advancedSettingsTiles(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations? l10n,
    required bool canAdminister,
    required Set<WorkspacePermission> perms,
    required bool devMode,
  }) =>
      [
          const Divider(),
          SettingsSectionHeader(l10n?.settingsSectionAdvanced ?? 'Advanced'),
          // #780 — which Supabase instance this device talks to: the
          // app's own by default, a community's own project if they
          // run one. Device-level, so it sits above the push state.
          const BackendSettingsTile(),
          // Push pipeline state (#424): a device without a UnifiedPush
          // distributor was silently push-less — say so, with the fix.
          const PushStatusTile(),
          // #917 — is this space real? Owner-only, and the one setting
          // that changes what every document says about itself.
          const WorkspaceEnvironmentTile(),
          // #945 — the workspace's sites, for those who manage it.
          if (perms.contains(WorkspacePermission.manageSites) &&
              ref
                  .watch(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.multiSite))
            ListTile(
              key: const ValueKey('settings-sites'),
              leading: const Icon(Icons.location_city_outlined),
              title: Text(l10n?.sitesTitle ?? 'Sites'),
              subtitle: Text(l10n?.sitesSubtitle ??
                  'Addresses, the levels at each, and who calls which home'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/settings/sites'),
            ),
          // #925 — one screen for every number series, owner-only.
          if (perms.contains(WorkspacePermission.manageBilling) &&
              ref
                  .watch(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.numberSequences))
            ListTile(
              key: const ValueKey('settings-number-sequences'),
              leading: const Icon(Icons.format_list_numbered_outlined),
              title: Text(l10n?.numberSequencesTitle ?? 'Number sequences'),
              subtitle: Text(
                l10n?.numberSequencesSubtitle ??
                    'How invoices and credit notes are numbered.',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/settings/number-sequences'),
            ),
          // #419: admins/owners flip dev mode for EVERYONE; other
          // members inherit the state without seeing the switch.
          if (ref.watch(myMemberProvider).value?.canAdminister ?? false)
            SwitchListTile(
              secondary: const Icon(Icons.developer_mode_outlined),
              title: Text(l10n?.developerMode ?? 'Developer mode'),
              subtitle: Text(
                l10n?.developerModeWorkspaceHint ??
                    'Applies to every member of this workspace.',
              ),
              value: devMode,
              onChanged: (v) => setWorkspaceDevMode(ref, v),
            ),
          if (devMode)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n?.developerTitle ?? 'Developer'),
              onTap: () => context.push('/developer'),
            ),
      ];

