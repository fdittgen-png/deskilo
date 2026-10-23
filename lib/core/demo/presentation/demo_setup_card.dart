// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide, inside the demo, first says what the demo is: nothing
// leaves the device, it can be reset at any time, which space and which
// persona the visitor is looking through — and the other space one tap
// away, Pézenas with every step done or Leipzig half way. Outside the demo
// it is nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';
import '../seed/demo_second_space_seed.dart';
import 'demo_workspace.dart';

class DemoSetupCard extends ConsumerWidget {
  const DemoSetupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = DemoEnvironment.maybeOf(context);
    if (env == null) return const SizedBox.shrink();
    final space = ref.watch(currentWorkspaceProvider).value;
    if (space == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final halfWay = space.id == demoSecondSpaceId;
    // The other space, when the persona is a member there.
    final other = ref
        .watch(myWorkspacesProvider)
        .value
        ?.where((w) => w.id == (halfWay ? 'ws-1' : demoSecondSpaceId))
        .firstOrNull;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('demo-setup-card'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.demoSetupCardTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.demoSetupCardBody),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.demoSetupCardWhere(
                space.name,
                DemoControls.personaLabel(l10n, env.persona),
              ),
            ),
            Text(
              halfWay ? l10n.demoSetupCardHalfDone : l10n.demoSetupCardComplete,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (other != null)
                  OutlinedButton(
                    key: const ValueKey('demo-setup-switch'),
                    onPressed: () => ref
                        .read(activeWorkspaceIdProvider.notifier)
                        .select(other.id),
                    child: Text(
                      halfWay
                          ? l10n.demoSetupCardOpenComplete(other.name)
                          : l10n.demoSetupCardOpenHalfDone(other.name),
                    ),
                  ),
                TextButton.icon(
                  key: const ValueKey('demo-setup-reset'),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.demoSessionReset),
                  onPressed: () => DemoControls.resetWithNotice(context, env),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
