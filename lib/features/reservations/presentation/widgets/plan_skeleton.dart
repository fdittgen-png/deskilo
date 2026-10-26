// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// #3068 — what Reserve shows while the floor plan loads: the shape of a
/// plan (a few rooms and desks) in the surface's own tones, so the page does
/// not jump when the plan arrives. Still, never animated: it holds under
/// reduced motion too.
class PlanSkeleton extends StatelessWidget {
  const PlanSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block(double flex, {double height = 96}) => Expanded(
      flex: (flex * 10).round(),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: tone, borderRadius: AppRadius.mdAll),
      ),
    );
    return Semantics(
      key: const ValueKey('reserve-plan-skeleton'),
      label: context.l10n.myReservationsLoadingMore,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: AppSpacing.lgAll,
          child: Column(
            spacing: AppSpacing.md,
            children: [
              Row(spacing: AppSpacing.md, children: [block(2), block(1)]),
              Row(spacing: AppSpacing.md, children: [block(1), block(1.5)]),
              Row(
                children: [
                  block(1, height: 72),
                  const SizedBox(width: 12),
                  block(2, height: 72),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
