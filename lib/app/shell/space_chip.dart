// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/workspace/presentation/widgets/workspace_avatar.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../route_classes.dart';

/// Workspace identity, deliberately not a workspace switcher.
class SpaceChip extends ConsumerWidget {
  const SpaceChip({super.key, required this.tabTitle});
  final String tabTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(currentWorkspaceProvider).value;
    final text = Theme.of(context).textTheme;
    return Row(
      key: const ValueKey('space-chip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (space != null) WorkspaceAvatar(workspace: space, radius: 16),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DesKilo · ${space?.name ?? ''}',
                key: const ValueKey('space-chip-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge,
              ),
              Text(
                tabTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The same account avatar, in the same position, in both layers.
class BackToMeButton extends StatelessWidget {
  const BackToMeButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('shell-back-to-me'),
    tooltip: AppLocalizations.of(context)?.spaceBackToMe ?? 'Back to Me',
    onPressed: () => context.go(kMeHome),
    icon: const PersonalAvatar(),
  );
}
