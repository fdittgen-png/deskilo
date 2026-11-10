// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/presentation/demo_workspace.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../domain/setup_level_demo.dart';
import '../../domain/setup_levels.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

/// One process: its name, the reason for its level, the level, and where
/// the demo shows it.
class SetupProcessChoice extends ConsumerWidget {
  const SetupProcessChoice({
    super.key,
    required this.process,
    required this.level,
    required this.reason,
    required this.onChanged,
    required this.onSeeDemo,
  });

  final SetupProcess process;
  final String level;
  final String? reason;
  final ValueChanged<String> onChanged;

  /// Opens the demo example at a route.
  final ValueChanged<String> onSeeDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #3235 — not inside the demo, and only where the demo is switched on.
    final demoOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.demoMode);
    final demo = DemoEnvironment.maybeOf(context) != null || !demoOn
        ? null
        : setupLevelDemoRoute(process, level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupProcessName(process.name),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reason != null) Text(reason!),
            if (demo != null)
              TextButton(
                key: ValueKey('setup-level-demo-${process.name}'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => onSeeDemo(demo),
                child: Text(l10n.setupLevelsSeeDemo),
              ),
          ],
        ),
        DropdownButton<String>(
          isExpanded: true,
          key: ValueKey('setup-level-${process.name}'),
          value: level,
          onChanged: (v) => v == null ? null : onChanged(v),
          items: [
            for (final l in setupLevels[process]!)
              DropdownMenuItem(
                key: ValueKey('setup-level-${process.name}-${l.id}'),
                value: l.id,
                child: Text(l10n.setupLevelName('${process.name}_${l.id}')),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
