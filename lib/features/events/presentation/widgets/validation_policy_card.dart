// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/validation_policy.dart';
import '../validation_workflow.dart';

class ValidationPolicyCard extends StatelessWidget {
  const ValidationPolicyCard({
    super.key,
    required this.label,
    required this.effective,
    required this.customized,
    required this.onEdit,
  });

  final String label;
  final ValidationPolicy effective;
  final bool customized;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = validationSteps(l10n, effective);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onEdit,
        child: Padding(
          padding: AppSpacing.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: HelpDotTitle(
                      label,
                      l10n?.helpHintValidationTopic ?? 'confirmations',
                      anchor: HelpAnchor.validationOverview,
                    ),
                  ),
                  // Whether this rule is its own or the default's is
                  // the difference between "I set that" and "that is
                  // just what happens", so both states are named.
                  // #1246 — Flexible + ellipsis: "Übernimmt
                  // Standardwert" pushed this row 44 px past a 360 px
                  // phone, which squeezed the title below the 48 dp its
                  // help symbol needs — one long word, three overflows.
                  Flexible(
                    child: Text(
                      customized
                          ? (l10n?.validationCustomized ?? 'Customized')
                          : (l10n?.validationInherited ?? 'Inherits default'),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: customized
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // #1221 — the rule AS THE PROCESS. It used to read
              // "2 required · All admins · Owner must always validate":
              // three true facts in a row, none of which says what
              // happens, in what order, or what is waiting meanwhile.
              _ProcessStrip(steps: steps),
              if (effective.minAmountCents > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n?.validationThresholdNote ??
                      'Smaller amounts apply straight away.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Who asks → who decides → what then, drawn as the three steps they
/// are (#1221).
class _ProcessStrip extends StatelessWidget {
  const _ProcessStrip({required this.steps});

  final ValidationSteps steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(IconData icon, String text, {bool strong = false}) => Expanded(
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: strong
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: strong
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: strong ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        );
    Widget arrow() => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.outlineVariant,
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        step(Icons.edit_note_outlined, steps.asked),
        arrow(),
        // The middle step is the one the owner edits, so it is the one
        // drawn in full weight.
        step(Icons.how_to_reg_outlined, steps.decide, strong: true),
        arrow(),
        step(Icons.check_circle_outline, steps.then),
      ],
    );
  }
}
