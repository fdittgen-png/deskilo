// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- Stock settings: every stock parameter on one page
// (`/stock/settings`): the stock features with their switches, and the stock
// rules of the settings registry. A stock setting shown elsewhere links here
// instead of being edited twice. The switches are the Features screen's own
// (consent, conflicts and all); the rules are the registry editor's own, so a
// new `stock.*` registry row appears here without a screen of its own.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/presentation/widgets/feature_switch_list.dart';
import '../../workspace/presentation/widgets/settings_editor.dart';
import '../../workspace/providers/workspace_providers.dart';
import 'stock_scan_settings.dart';

/// The stock features, parents first.
const stockSettingsFeatures = [
  WorkspaceFeature.stockManagement,
  WorkspaceFeature.stockLots,
  WorkspaceFeature.stockReceiving,
];

class StockSettingsScreen extends ConsumerWidget {
  const StockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final held = ref.watch(myPermissionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockSettingsTitle),
        actions: [HelpDot(l10n.permModuleStock, anchor: HelpAnchor.moneyStock)],
      ),
      body: workspace == null
          ? const LoadingView()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (held.contains(WorkspacePermission.manageConfiguration)) ...[
                      Text(l10n.stockSettingsFeatures, style: Theme.of(context).textTheme.titleMedium),
                      const FeatureSwitchList(
                        key: ValueKey('stock-settings-features'),
                        features: stockSettingsFeatures,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(l10n.stockSettingsValues, style: Theme.of(context).textTheme.titleMedium),
                    SettingsEditor(
                      scope: SettingScope.workspace,
                      workspaceId: workspace.id,
                      keyPrefix: 'stock.',
                      canEdit: held.contains(WorkspacePermission.workspaceSettings),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const StockScanSettings(),
                  ],
                ),
              ),
            ),
    );
  }
}
