// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — inside a space, the bar always says WHICH space: a chip with
// its initial and name (the tab below it), opening a switcher with every
// space and "Back to Me". Beside it, my own avatar returns to Me in one
// tap. The person is never unsure whether they are in a space or in
// their own layer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../route_classes.dart';
import 'space_entry.dart';

class SpaceChip extends ConsumerWidget {
  const SpaceChip({super.key, required this.tabTitle});

  /// The destination inside the space, under its name.
  final String tabTitle;

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final spaces = ref.read(myWorkspacesProvider).value ?? const <Workspace>[];
    final current = ref.read(currentWorkspaceProvider).value?.id;
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const ValueKey('space-switcher-back-to-me'),
              leading: const Icon(Icons.person_outline),
              title: Text(l10n?.spaceBackToMe ?? 'Back to Me'),
              onTap: () => Navigator.of(sheetContext).pop(kMeHome),
            ),
            const Divider(),
            for (final space in spaces)
              ListTile(
                key: ValueKey('space-switcher-${space.id}'),
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(space.name),
                trailing: space.id == current
                    ? const Icon(Icons.check_circle_outline)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(space),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (picked == kMeHome) {
      context.go(kMeHome);
    } else if (picked is Workspace && picked.id != current) {
      await enterSpace(context, ref, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = ref.watch(currentWorkspaceProvider).value?.name ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final text = Theme.of(context).textTheme;
    return Tooltip(
      message: l10n?.spaceChipTooltip ?? 'Switch space',
      child: InkWell(
        key: const ValueKey('space-chip'),
        borderRadius: AppRadius.xxlAll,
        onTap: () => _switch(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 14, child: Text(initial)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        key: const ValueKey('space-chip-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge),
                    Text(tabTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// My avatar in the space's bar: one tap back to Me.
class BackToMeButton extends ConsumerWidget {
  const BackToMeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = ref.watch(myProfileProvider).value?.displayName ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: const ValueKey('shell-back-to-me'),
      tooltip: l10n?.spaceBackToMe ?? 'Back to Me',
      onPressed: () => context.go(kMeHome),
      // The initial on the theme's own pair, so it reads on any bar.
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: Text(initial),
      ),
    );
  }
}
