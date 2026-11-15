// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

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
import 'chrome_role.dart';
import 'house_switch.dart';
import 'space_entry.dart';

/// The side of the ring a branded space's avatar wears on the chip.
const double _ringSide = 38;

/// The radius of the space's avatar on the chip.
const double _avatarRadius = 16;

/// The least the page's name is scaled to before it is cut instead: at
/// 0.8 a title set at 16 reads like the body text beside it.
const double _minTitleScale = 0.8;

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

/// Workspace identity, not a workspace switcher — except, #4006, between the
/// houses of one organisation: a tap opens their sheet. The page's
/// name comes first and is never cut where the box can hold it: the avatar
/// is dropped where it would crowd the name out, and the business's line
/// is left out where it cannot be read whole — the drawer names it.
class SpaceChip extends ConsumerWidget {
  const SpaceChip({super.key, required this.tabTitle, this.path});
  final String tabTitle;

  /// #4019 — the page's path: where it declares that the role decides it,
  /// the business's line names the role too.
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final space = ref.watch(currentWorkspaceProvider).value;
    final text = Theme.of(context).textTheme;
    final brand = space == null ? null : spaceBrand(space);
    final avatarSide = brand != null ? _ringSide : 2 * _avatarRadius;
    final houses = otherHousesOf(ref, space?.id);
    final role = chromeRoleFor(context, ref, path);
    final chip = LayoutBuilder(
      builder: (context, constraints) {
        final page = _lineWidth(context, tabTitle, text.titleMedium);
        final withAvatar =
            space != null &&
            avatarSide + AppSpacing.sm + page <= constraints.maxWidth;
        final column =
            constraints.maxWidth -
            (withAvatar ? avatarSide + AppSpacing.sm : 0);
        final plain = space == null ? null : '${l10n.appTitle} · ${space.name}';
        // #4019 — the role joins the business's line only where the whole
        // line is still read; never at the price of the page's name.
        final withRole = plain == null || role == null
            ? null
            : '$plain · $role';
        final business =
            withRole != null &&
                _lineWidth(context, withRole, text.labelLarge) <= column
            ? withRole
            : plain;
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
                  // #4030 — where even the bar's controls in the menu leave
                  // too little room, the page's name shrinks rather than
                  // being cut — down to [_minTitleScale], no further: a
                  // name the reader enlarged must not end up smaller than
                  // the text around it. Beyond that it is cut, and still
                  // read whole.
                  if (page * _minTitleScale <= column)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        tabTitle,
                        key: const ValueKey('space-chip-page'),
                        maxLines: 1,
                        softWrap: false,
                        style: text.titleMedium,
                      ),
                    )
                  else
                    Text(
                      tabTitle,
                      key: const ValueKey('space-chip-page'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: tabTitle,
                      style: text.titleMedium,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
    // #4019 — one label, "<business>, <page>[, <role>]"; where it switches houses it
    // ends with the tooltip's words, and it is a button only then.
    // #4019 — a consequential page adds the role whether or not the bar has
    // room to draw it: a screen reader hears it at any width.
    final base = space == null ? tabTitle : '${space.name}, $tabTitle';
    final label = role == null ? base : '$base, $role';
    if (houses.isEmpty) {
      return Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: chip,
      );
    }
    return Tooltip(
      message: l10n.spaceOtherHouses,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        label: '$label, ${l10n.spaceOtherHouses}',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('space-chip-houses'),
          onTap: () async {
            final picked = await HouseSheet.open(context, houses);
            if (picked == null || !context.mounted) return;
            unawaited(enterSpace(context, ref, picked));
          },
          // The tap is a whole target: the chip is 44 high, the tap 48 (#4036).
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: chip,
            ),
          ),
        ),
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
