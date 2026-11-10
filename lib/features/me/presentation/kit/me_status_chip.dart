// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- a status mark: the tint pairs of the personal theme.
import 'package:flutter/material.dart';

import '../../../../core/theme/personal_theme.dart';

/// What the chip says about its row.
enum MeChipKind { toPay, overdue, ok, neutral }

class MeStatusChip extends StatelessWidget {
  const MeStatusChip({super.key, required this.kind, required this.label});

  final MeChipKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    final (background, foreground) = switch (kind) {
      MeChipKind.toPay => (tokens.warningTint, tokens.warning),
      MeChipKind.overdue => (tokens.dangerTint, tokens.danger),
      MeChipKind.ok => (tokens.successTint, tokens.success),
      MeChipKind.neutral => (tokens.subtle, tokens.secondaryText),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: PersonalShellMetrics.controlRadiusAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
          ),
        ),
      ),
    );
  }
}
