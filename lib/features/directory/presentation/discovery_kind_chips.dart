// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3554 — Discover narrows by kind of business. The chips are the app's own
// catalogue, never the kinds the loaded results contain: a practice on a
// source's second page is still choosable. They sit above the results, so a
// chosen kind stays chosen while a listing loads, finds nothing or fails;
// "All kinds" is always the way back. No counts: a partly loaded listing
// cannot say how many there are.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../workspace/presentation/business_kind_names.dart';

class DiscoveryKindChips extends StatelessWidget {
  const DiscoveryKindChips({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The chosen kind code, or null for every kind.
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              key: const ValueKey('directory-kind-all'),
              label: Text(l10n.discoveryKindAll),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final code in discoverableBusinessKinds)
              if (businessKindChipLabel(l10n, code) case final label?)
                ChoiceChip(
                  key: ValueKey('directory-kind-$code'),
                  label: Text(label),
                  selected: selected == code,
                  onSelected: (_) => onChanged(code),
                ),
          ],
        ),
      ),
    );
  }
}
