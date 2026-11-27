// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- the parts an item's page is made of: a section (a card with its title, what it shows and its worded
// actions), a fact (a label over its value) and a line (a title over a second line). Kit cards, theme type and
// spacing tokens only, so the page reads the same in light and dark and at every width.
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/kit_card.dart';

/// One section of an item's page: [title], what it shows, and its [actions] (none for a reader).
class StockItemSection extends StatelessWidget {
  const StockItemSection({
    super.key,
    required this.title,
    required this.lines,
    this.actions = const [],
  });

  final String title;

  /// What the section shows.
  final List<Widget> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitLabel(title),
          const FormGap.small(),
          ...lines,
          if (actions.isNotEmpty) ...[
            const FormGap.small(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    ),
  );
}

/// A label over its value.
class StockItemFact extends StatelessWidget {
  const StockItemFact({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// Facts side by side, wrapping onto the next line where the width ends.
class StockItemFacts extends StatelessWidget {
  const StockItemFacts({super.key, required this.facts});

  final List<StockItemFact> facts;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpacing.xl, runSpacing: AppSpacing.md, children: facts);
}

/// A line of a section: [title] over [subtitle], with an optional action under them.
class StockItemLine extends StatelessWidget {
  const StockItemLine({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle case final s?)
            Text(
              s,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ?action,
        ],
      ),
    );
  }
}
