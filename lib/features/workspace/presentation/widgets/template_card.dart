// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/template_capabilities.dart';
import '../../domain/workspace_template.dart';
import 'template_why_match.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    this.selected,
    this.onTap,
    this.trailing,
    this.shortlisted,
    this.onShortlist,
    this.evidence,
  });

  final WorkspaceTemplate template;

  /// #1660 — what this template says about each capability searched for;
  /// null or empty outside a capability search.
  final Map<String, CapabilityEvidence>? evidence;

  /// #1660 — whether it is on the compare shortlist; null hides the toggle.
  final bool? shortlisted;
  final VoidCallback? onShortlist;

  /// Null outside selection mode.
  final bool? selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = template.counts;
    final gives = [
      l10n?.libraryCounts(c.levels, c.desks, c.seats) ??
          '${c.levels} levels · ${c.desks} desks · ${c.seats} seats',
      if (template.carriesConfiguration)
        l10n?.libraryCarriesSettings ?? 'with its settings',
    ].join(' · ');
    final visibility = switch (template.visibility) {
      TemplateVisibility.builtin =>
        l10n?.libraryVisibilityBuiltin ?? 'Built in',
      TemplateVisibility.private => l10n?.libraryVisibilityPrivate ?? 'Only me',
      TemplateVisibility.shared =>
        l10n?.libraryVisibilityShared ?? 'People I invite',
      TemplateVisibility.public =>
        l10n?.libraryVisibilityPublic ?? 'Everyone (the library)',
      TemplateVisibility.unknown => '',
    };
    final lines = [
      gives,
      if (template.description.isNotEmpty) template.description,
      [
        if (template.tags.isNotEmpty) template.tags.join(', '),
        if (visibility.isNotEmpty) visibility,
      ].join(' · '),
    ];
    final isSelected = selected ?? false;
    return Card(
      // The selection keys stay the ones onboarding tests pin; the
      // library's row key stays the library's.
      key: ValueKey(
        selected == null
            ? 'library-template-${template.key}'
            : 'template-${template.key}',
      ),
      color: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(isSelected ? Icons.check : Icons.grid_view_outlined),
            title: Text(template.name),
            subtitle: Text(lines.where((l) => l.isNotEmpty).join('\n')),
            isThreeLine: lines.where((l) => l.isNotEmpty).length > 2,
            selected: isSelected,
            onTap: onTap,
            trailing: shortlisted == null
                ? trailing
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('template-shortlist-${template.key}'),
                        tooltip: shortlisted!
                            ? (l10n?.compareRemove ?? 'Remove from comparison')
                            : (l10n?.compareAdd ?? 'Add to comparison'),
                        isSelected: shortlisted,
                        icon: const Icon(Icons.add_chart_outlined),
                        selectedIcon: const Icon(Icons.bar_chart),
                        onPressed: onShortlist,
                      ),
                      ?trailing,
                    ],
                  ),
          ),
          if (evidence case final e? when e.isNotEmpty)
            TemplateWhyMatch(templateKey: template.key, evidence: e),
        ],
      ),
    );
  }
}
