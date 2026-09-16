// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/push/push_status_tile.dart';
import '../../../../core/scan/front_camera.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/application/set_workspace_dev_mode.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'backend_settings_tile.dart';
import 'settings_section_header.dart';

/// #1307 — the Advanced section: THIS DEVICE and diagnostics — which
/// backend it talks to, the push pipeline, the scan camera, developer mode
/// and demo mode. The workspace's own settings (environment, sites, number
/// sequences) moved to the sections they configure in S3.
///
/// Extracted so Settings can be reorganized by ownership at all:
/// `settings_screen.dart` sat at exactly its length cap, which meant
/// nothing could be added before something left. The tiles are
/// unchanged — only the list is cut, the same way #1154 cut About.
List<Widget> advancedSettingsTiles(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations? l10n,
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
          // Which camera reads badge QR codes: front by default (a
          // wall-mounted kiosk's back lens faces the wall). Device-local
          // preference, like language and theme.
          SwitchListTile(
            key: const ValueKey('settings-front-camera'),
            secondary: const Icon(Icons.camera_front_outlined),
            title: HelpDotTitle(
              l10n?.settingsFrontCamera ?? 'Scan with the front camera',
              l10n?.helpTopicSettings ?? 'Settings & profile',
              anchor: HelpAnchor.profileFrontCamera,
            ),
            subtitle: Text(
              l10n?.settingsFrontCameraDesc ??
                  'Badges are read with the screen-side camera — turn '
                      'off to use the back camera.',
            ),
            value: ref.watch(frontCameraScanProvider).value ?? true,
            onChanged: (v) =>
                ref.read(frontCameraScanProvider.notifier).setEnabled(v),
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
          // #970 — demo mode: invented names, e-mails and addresses on
          // this device, for screenshots and recordings.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.demoMode))
            SwitchListTile(
              key: const ValueKey('settings-demo-mode'),
              secondary: const Icon(Icons.visibility_off_outlined),
              title: HelpDotTitle(
                l10n?.demoModeTitle ?? 'Demo mode',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profileDemoMode,
              ),
              subtitle: Text(l10n?.demoModeSubtitle ??
                  'Names, e-mails, phones and addresses are blurred on '
                      'this device\'s screen — for screenshots and videos.'),
              value: ref.watch(demoModeControllerProvider).value ?? false,
              onChanged: (on) =>
                  ref.read(demoModeControllerProvider.notifier).set(on),
            ),
      ];
