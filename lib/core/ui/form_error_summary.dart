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

/// #4065 — a field the summary names, and how to reach it.
typedef FormProblem = ({Key key, String label, VoidCallback onGo});

class FormErrorSummary extends StatelessWidget {
  const FormErrorSummary({
    super.key,
    required this.count,
    required this.onGoToFirst,
    this.problems = const [],
  });

  /// How many fields have a problem; the summary shows nothing for none.
  final int count;

  /// Moves the focus to the first field with a problem.
  final VoidCallback onGoToFirst;

  /// #4065 — the fields with a problem, each named by its label: a link
  /// that moves the focus to it. Where given, they stand for the one
  /// "Go to the first problem".
  final List<FormProblem> problems;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final link = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: scheme.onErrorContainer,
    );
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
                if (problems.isEmpty)
                  TextButton(
                    key: const ValueKey('form-error-summary-go'),
                    style: link,
                    onPressed: onGoToFirst,
                    child: Text(l10n.formErrorSummaryGoTo),
                  ),
                for (final p in problems)
                  TextButton(
                    key: p.key,
                    style: link,
                    onPressed: p.onGo,
                    child: Text(p.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
