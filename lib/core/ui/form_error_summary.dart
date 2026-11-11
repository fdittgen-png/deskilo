// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — the summary a form shows above its fields when a check found
// problems: how many fields need attention, and one action that moves the
// focus to the first of them. The sentences stay under their own fields
// (FormErrorsScope); this only says there are some and takes the person
// there, so a keyboard or screen-reader user is not left at the Save
// button with the problem somewhere above.
import 'package:flutter/material.dart';

import '../l10n/context_l10n.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class FormErrorSummary extends StatelessWidget {
  const FormErrorSummary({
    super.key,
    required this.count,
    required this.onGoToFirst,
  });

  /// How many fields have a problem; the summary shows nothing for none.
  final int count;

  /// Moves the focus to the first field with a problem.
  final VoidCallback onGoToFirst;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: AppRadius.mdAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                Text(
                  l10n.formErrorSummaryTitle(count),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                TextButton(
                  key: const ValueKey('form-error-summary-go'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: scheme.onErrorContainer,
                  ),
                  onPressed: onGoToFirst,
                  child: Text(l10n.formErrorSummaryGoTo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
