// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// One identity, with its environment actions kept together at every width.
class MeWorkspaceRow extends StatelessWidget {
  const MeWorkspaceRow({
    super.key,
    required this.avatar,
    required this.name,
    required this.detail,
    required this.actions,
  });
  final Widget avatar;
  final String name, detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              avatar,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          );
          final environments = Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          );
          // Large text gets the same stacked identity as a small viewport;
          // environments remain next to each other, with horizontal scrolling
          // only when accessibility text cannot fit both controls.
          if (constraints.maxWidth /
                  MediaQuery.textScalerOf(context).scale(1) >=
              600) {
            return Row(
              children: [
                Expanded(child: identity),
                environments,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: environments,
              ),
            ],
          );
        },
      ),
    ),
  );
}
