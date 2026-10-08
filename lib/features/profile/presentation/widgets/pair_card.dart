// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

import '../../../workspace/presentation/widgets/workspace_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../workspace/domain/workspace.dart';

/// #987 — a workspace and its twin as ONE card: the name once, two
/// chips (DEV · PROD) to switch sides, the active side marked. The
/// couple is the unit the owner thinks in; two unrelated entries were
/// two chances to bill real people from the wrong one.
class WorkspacePairCard extends StatelessWidget {
  const WorkspacePairCard({
    super.key,
    required this.dev,
    required this.prod,
    required this.activeId,
    required this.onSelect,
    this.roleLabel,
  });

  final Workspace dev;
  final Workspace prod;
  final String? activeId;
  final Future<void> Function(String workspaceId) onSelect;

  /// The viewer's role on the active side, when known.
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = l10n ?? AppLocalizationsEn();
    final devActive = activeId == dev.id;
    final prodActive = activeId == prod.id;
    final active = devActive || prodActive;
    final theme = Theme.of(context);
    Widget environment(Workspace workspace, bool selected, String label, String key) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(width: double.infinity, child: OutlinedButton(
        key: ValueKey(key),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56), padding: AppSpacing.lgAll,
          backgroundColor: selected ? theme.colorScheme.secondaryContainer : null,
          foregroundColor: selected ? theme.colorScheme.onSecondaryContainer : null,
        ),
        onPressed: () => onSelect(workspace.id),
        child: Row(children: [
          Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
              semanticLabel: selected ? (l10n?.profilesActive ?? 'Active profile') : null),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label)),
        ]),
      )),
    );
    final devLabel = l10n?.environmentDev ?? 'Development';
    final prodLabel = l10n?.environmentProd ?? 'Production';
    return Card(
      key: ValueKey('profile-pair-${dev.pairId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: active ? theme.colorScheme.surfaceContainer : null,
      child: ExpansionTile(
        initiallyExpanded: active,
        shape: const Border(), collapsedShape: const Border(),
        tilePadding: AppSpacing.lgAll, childrenPadding: AppSpacing.lgH,
        leading: WorkspaceAvatar(workspace: prodActive ? prod : dev),
        title: Text(dev.name, style: theme.textTheme.primaryValue?.strong),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (roleLabel != null) Text(roleLabel!, style: theme.textTheme.metadata),
          Text(active ? (prodActive ? prodLabel : devLabel)
              : labels.uxProfileChooseEnvironment),
        ]),
        children: [
          environment(dev, devActive, devLabel, 'profile-pair-dev-${dev.pairId}'),
          environment(prod, prodActive, prodLabel, 'profile-pair-prod-${dev.pairId}'),
        ],
      ),
    );
  }
}
