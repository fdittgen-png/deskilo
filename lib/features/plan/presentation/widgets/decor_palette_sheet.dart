// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — the shapes the owner draws the real room with: tap one, then tap
// the plan to drop it. Walls, doors and windows frame the room; the pillar,
// table, couch, WC and kitchen furnish it.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/floor_plan.dart';
import '../../domain/floor_plan_editing.dart';

/// The word a symbol goes by.
String decorKindLabel(AppLocalizations l10n, PlanDecorKind kind) =>
    switch (kind) {
      PlanDecorKind.wall => l10n.decorWall,
      PlanDecorKind.door => l10n.decorDoor,
      PlanDecorKind.window => l10n.decorWindow,
      PlanDecorKind.pillar => l10n.decorPillar,
      PlanDecorKind.table => l10n.decorTable,
      PlanDecorKind.couch => l10n.decorCouch,
      PlanDecorKind.wc => l10n.decorWc,
      PlanDecorKind.kitchen => l10n.decorKitchen,
    };

IconData _icon(PlanDecorKind kind) => switch (kind) {
  PlanDecorKind.wall => Icons.horizontal_rule,
  PlanDecorKind.door => Icons.door_front_door_outlined,
  PlanDecorKind.window => Icons.window_outlined,
  PlanDecorKind.pillar => Icons.circle_outlined,
  PlanDecorKind.table => Icons.table_bar_outlined,
  PlanDecorKind.couch => Icons.weekend_outlined,
  PlanDecorKind.wc => Icons.wc_outlined,
  PlanDecorKind.kitchen => Icons.kitchen_outlined,
};

/// The drawn symbol selected on [plan], or null when the selection is a
/// photo or nothing.
PlanImage? selectedDecorOf(FloorPlan plan, ElementKind? kind, String? id) =>
    kind == ElementKind.image
    ? plan.images.where((i) => i.id == id && i.kind != null).firstOrNull
    : null;

/// What the selection bar calls a selected image: the symbol's word, or
/// "Image" for a photo.
String decorOrImageName(AppLocalizations l10n, PlanImage? decor) {
  final kind = decor?.kind;
  return kind == null ? l10n.editorToolImage : decorKindLabel(l10n, kind);
}

/// Asks which symbol to draw; null when dismissed.
Future<PlanDecorKind?> pickDecorKind(BuildContext context) =>
    showAppSheet<PlanDecorKind>(
      context: context,
      builder: (context) => const _DecorPalette(),
    );

class _DecorPalette extends StatelessWidget {
  const _DecorPalette();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            Text(
              l10n.editorToolDecor,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(l10n.editorDecorPaletteHint),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final kind in PlanDecorKind.values)
                  ActionChip(
                    key: ValueKey('decor-kind-${kind.name}'),
                    avatar: Icon(_icon(kind), size: 18),
                    label: Text(decorKindLabel(l10n, kind)),
                    onPressed: () => Navigator.of(context).pop(kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
