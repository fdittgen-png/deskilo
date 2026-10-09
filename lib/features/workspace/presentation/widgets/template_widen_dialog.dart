// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/template_inspection.dart';
import '../../domain/workspace_template.dart';
import 'template_group_label.dart';

/// #1658 — how far a visibility reaches: private < shared < public.
int templateVisibilityReach(TemplateVisibility v) => switch (v) {
  TemplateVisibility.private => 0,
  TemplateVisibility.shared => 1,
  TemplateVisibility.public => 2,
  _ => 3,
};

/// #1658 — before a template reaches more people: what they will be able
/// to read, from the SERVER's inspection of the template as it stands (the
/// settings it carries, the parts they come in) and what it never
/// carries. True only on an explicit confirmation.
Future<bool> showTemplateWidenDialog(
  BuildContext context, {
  required TemplateInspection inspection,
  required TemplateVisibility to,
}) async {
  final l10n = AppLocalizations.of(context);
  final audience = switch (to) {
    TemplateVisibility.shared =>
      l10n?.libraryVisibilityShared ?? 'People I invite',
    _ => l10n?.libraryVisibilityPublic ?? 'Everyone (the library)',
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('template-widen'),
      title: Text(
        l10n?.templateWidenTitle(audience) ??
            'Make this template readable by: $audience?',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key: const ValueKey('template-widen-count'),
              l10n?.templateWidenCount('${inspection.coverage.present}') ??
                  '${inspection.coverage.present} settings become readable, '
                      'exactly as the template holds them now.',
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final g in inspection.outline.groups)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                child: Text(templateGroupLabel(l10n, g)),
              ),
            if (inspection.exclusions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                key: const ValueKey('template-widen-excluded'),
                l10n?.templateWidenExcluded(
                      '${inspection.exclusions.length}',
                    ) ??
                    '${inspection.exclusions.length} kinds of value never '
                        'leave with it (bank details, sites, addresses…).',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ValueKey('template-widen-dialog-text-button-${to.name}'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('template-widen-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n?.templateWidenConfirm ?? 'Make readable'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
