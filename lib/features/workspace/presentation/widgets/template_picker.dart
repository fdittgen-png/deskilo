// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_template.dart';
import '../../providers/workspace_providers.dart';

/// #1120 — "Start from": the templates a person may read, as cards, one
/// selected. Null selection means an empty canvas.
///
/// No feature flag here on purpose: at onboarding there is no workspace
/// yet to hold a flag, and a new space starting with a room is the whole
/// point of #1120's first step. The server decides which rows are
/// readable; the picker shows what it returned, builtin first.
class TemplatePicker extends ConsumerWidget {
  const TemplatePicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final templates = ref.watch(workspaceTemplatesProvider).value ?? const [];
    final sorted = [...templates]
      ..sort((a, b) => a.isBuiltin == b.isBuiltin
          ? a.name.compareTo(b.name)
          : (a.isBuiltin ? -1 : 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.onboardingStartFrom ?? 'Start from',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in sorted)
              _TemplateCard(
                key: ValueKey('template-${t.key}'),
                title: t.name,
                subtitle: _counts(l10n, t),
                selected: t.id == selectedId,
                onTap: () => onChanged(t.id),
              ),
            _TemplateCard(
              key: const ValueKey('template-empty'),
              title: l10n?.onboardingStartEmpty ?? 'Empty space',
              subtitle: l10n?.onboardingStartEmptyDesc ??
                  'Draw your own plan from a blank canvas.',
              selected: selectedId == null,
              onTap: () => onChanged(null),
            ),
          ],
        ),
      ],
    );
  }

  static String _counts(AppLocalizations? l10n, WorkspaceTemplate t) {
    final c = t.counts;
    return l10n?.libraryCounts(c.levels, c.desks, c.seats) ??
        '${c.levels} levels · ${c.desks} desks · ${c.seats} seats';
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(selected ? Icons.check : Icons.grid_view_outlined,
          size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
