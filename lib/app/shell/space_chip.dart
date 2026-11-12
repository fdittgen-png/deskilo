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

/// The width [text] takes on one line in [style], as [context] paints it.
double _lineWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Workspace identity, deliberately not a workspace switcher. The page's
/// name comes first and is never cut where the box can hold it: the avatar
/// is dropped where it would crowd the name out, and the business's line
/// is left out where it cannot be read whole — the drawer names it.
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
      builder: (context, constraints) {
        final page = _lineWidth(context, tabTitle, text.titleMedium);
        final withAvatar =
            space != null &&
            avatarSide + AppSpacing.sm + page <= constraints.maxWidth;
        final column =
            constraints.maxWidth -
            (withAvatar ? avatarSide + AppSpacing.sm : 0);
        final business = space == null
            ? null
            : '${l10n.appTitle} · ${space.name}';
        final showBusiness =
            business != null &&
            _lineWidth(context, business, text.labelLarge) <= column;
        return Row(
          key: const ValueKey('space-chip'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withAvatar) ...[
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
                  if (showBusiness)
                    Text(
                      business,
                      key: const ValueKey('space-chip-name'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                  Text(
                    tabTitle,
                    key: const ValueKey('space-chip-page'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
