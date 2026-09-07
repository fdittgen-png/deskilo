// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
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
    final brightness = Theme.of(context).brightness;
    final devActive = activeId == dev.id;
    final prodActive = activeId == prod.id;
    return Card(
      key: ValueKey('profile-pair-${dev.pairId}'),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: prodActive
              ? AppEnvironmentColors.productionOf(brightness)
              : AppEnvironmentColors.developmentOf(brightness),
          foregroundColor: Colors.white,
          child: Text(dev.name.isEmpty
              ? '?'
              : dev.name.substring(0, 1).toUpperCase()),
        ),
        title: Text(dev.name),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              key: ValueKey('profile-pair-dev-${dev.pairId}'),
              label: Text(l10n?.profilesPairDev ?? 'DEV'),
              selected: devActive,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelect(dev.id),
            ),
            ChoiceChip(
              key: ValueKey('profile-pair-prod-${dev.pairId}'),
              label: Text(l10n?.profilesPairProd ?? 'PROD'),
              selected: prodActive,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelect(prod.id),
            ),
            if (roleLabel != null)
              Text(roleLabel!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: (devActive || prodActive)
            ? Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: l10n?.profilesActive ?? 'Active profile')
            : null,
      ),
    );
  }
}
