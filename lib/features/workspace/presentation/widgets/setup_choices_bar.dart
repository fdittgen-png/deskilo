// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// The draft state, impact review and apply action remain visible while scrolling.
class SetupChoicesBar extends StatelessWidget {
  const SetupChoicesBar({
    super.key,
    required this.changeCount,
    required this.workspaceName,
    required this.unchanged,
    required this.unresolved,
    required this.busy,
    required this.disabled,
    required this.onReview,
    required this.onApply,
  });

  final String workspaceName;
  final int changeCount;
  final bool unchanged;
  final bool unresolved;
  final bool busy;
  final bool disabled;
  final VoidCallback onReview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.mdAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                workspaceName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                unresolved
                    ? l10n.setupChoicesNeedsDecision
                    : unchanged
                    ? l10n.setupChoicesDetails
                    : l10n.setupChoicesUnsaved,
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                children: [
                  TextButton(
                    key: const ValueKey('setup-choices-review'),
                    onPressed: onReview,
                    child: Text(l10n.setupChoicesSummary(changeCount)),
                  ),
                  FilledButton(
                    key: const ValueKey('setup-levels-apply'),
                    onPressed: unchanged || disabled || unresolved || busy
                        ? null
                        : onApply,
                    child: Text(
                      busy ? l10n.setupChoicesSaving : l10n.setupLevelsApply,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
