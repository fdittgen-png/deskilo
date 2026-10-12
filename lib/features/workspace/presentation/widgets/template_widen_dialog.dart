// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
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
  final l10n = context.l10n;
  final audience = switch (to) {
    TemplateVisibility.shared =>
      l10n.libraryVisibilityShared,
    _ => l10n.libraryVisibilityPublic,
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('template-widen'),
      title: Text(
        l10n.templateWidenTitle(audience),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key: const ValueKey('template-widen-count'),
              l10n.templateWidenCount('${inspection.coverage.present}'),
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
                l10n.templateWidenExcluded(
                      '${inspection.exclusions.length}',
                    ),
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
          child: Text(l10n.templateWidenConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
