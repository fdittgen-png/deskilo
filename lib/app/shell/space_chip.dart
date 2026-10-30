// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/workspace/presentation/widgets/brand_swatch.dart';
import '../../features/workspace/presentation/widgets/workspace_avatar.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_classes.dart';

/// The side of the ring a branded space's avatar wears on the chip.
const double _ringSide = 38;

/// The radius of the space's avatar on the chip.
const double _avatarRadius = 16;

/// The narrowest name column worth keeping the avatar for: below the room
/// for the avatar, its gap and this, the chip shows the name alone.
const double _minNameWidth = 64;

/// Workspace identity, deliberately not a workspace switcher. It fits any
/// title box the app bar leaves it: the avatar is dropped where it would
/// crowd out the name, and the name ellipsizes.
class SpaceChip extends ConsumerWidget {
  const SpaceChip({super.key, required this.tabTitle});
  final String tabTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final space = ref.watch(currentWorkspaceProvider).value;
    final text = Theme.of(context).textTheme;
    final brand = space == null ? null : spaceBrand(space);
    final avatarSide = brand != null ? _ringSide : 2 * _avatarRadius;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        key: const ValueKey('space-chip'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (space != null &&
              constraints.maxWidth >=
                  avatarSide + AppSpacing.sm + _minNameWidth) ...[
            if (brand != null)
              // #2313 — a ring in the space's colour and pattern.
              SizedBox.square(
                key: const ValueKey('space-chip-brand'),
                dimension: _ringSide,
                child: ClipOval(
                  child: BrandSwatch(
                    color: brand.color,
                    pattern: brand.pattern,
                    child: Center(
                      child: WorkspaceAvatar(
                        workspace: space,
                        radius: _avatarRadius,
                      ),
                    ),
                  ),
                ),
              )
            else
              WorkspaceAvatar(workspace: space, radius: _avatarRadius),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.appTitle} · ${space?.name ?? ''}',
                  key: const ValueKey('space-chip-name'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge,
                ),
                Text(
                  tabTitle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The same account avatar, in the same position, in both layers.
class BackToMeButton extends StatelessWidget {
  const BackToMeButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('shell-back-to-me'),
    tooltip: context.l10n.spaceBackToMe,
    onPressed: () => context.go(kMeHome),
    icon: const PersonalAvatar(),
  );
}
