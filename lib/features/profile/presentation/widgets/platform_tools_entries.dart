// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The platform owner's tools, listed in the platform section of the profile
// list (#937): reference data and defaults that belong to the installation,
// not to one workspace. Server-gated (`is_platform_owner`), no feature flag
// (docs/AGENT_RULES.md, "The platform-owner overview has no feature flag").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/settings.dart';
import '../../../money/presentation/screens/tax_reference_screen.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/presentation/widgets/settings_editor.dart';
import '../../../workspace/providers/workspace_providers.dart';

class PlatformToolsEntries extends ConsumerWidget {
  const PlatformToolsEntries({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: [
          // #2477 — rates, statutory texts and VAT id patterns.
          ListTile(
            key: const ValueKey('profiles-tax-reference'),
            leading: const Icon(Icons.percent),
            title: Text(context.l10n.taxRefTitle),
            onTap: () => showTaxReferenceScreen(context, canEdit: true),
          ),
          // #2484 — the platform's default values of the settings registry.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.configurableSettings))
            ListTile(
              key: const ValueKey('profiles-platform-settings'),
              leading: const Icon(Icons.tune_outlined),
              title: Text(context.l10n.settingsPlatformTitle),
              onTap: () => showSettingsEditorSheet(
                context,
                title: context.l10n.settingsPlatformTitle,
                scope: SettingScope.platform,
                canEdit: true,
              ),
            ),
        ],
      );
}
