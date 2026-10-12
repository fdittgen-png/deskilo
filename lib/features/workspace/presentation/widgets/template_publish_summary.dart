// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/local_setup_providers.dart';
import 'local_setup_views.dart';

/// #1658 — which profile the publication is: the whole configuration, or
/// a named selection of its groups.
class TemplateProfileLine extends StatelessWidget {
  const TemplateProfileLine({
    super.key,
    required this.chosen,
    required this.total,
  });
  final int chosen;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final full = chosen >= total;
    return Text(
      key: const ValueKey('save-template-profile'),
      full
          ? (l10n.templateProfileFull)
          : (l10n.templateProfileSelected('$chosen', '$total')),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// #1658 — what a space that applies this template will have to set up
/// itself for the features it carries: the same slots this space needs,
/// named, never their values (a template carries no identity, bank or
/// provider account).
class TemplateLocalNeedsPreview extends ConsumerWidget {
  const TemplateLocalNeedsPreview({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final slots =
        ref.watch(workspaceLocalSlotsProvider(workspaceId)).value ?? const [];
    if (slots.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('save-template-local-needs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.templatePublishLocalNeeds,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [for (final s in slots) localSlotLabel(l10n, s.kind, s.eventType)]
              .join(' · '),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
