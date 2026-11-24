// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/kit/kit_card.dart';
import '../domain/public_workspace.dart';
import 'public_facet_labels.dart';

/// The same published facts on a comparison card and the full public page.
class PublicProfileFacts extends StatelessWidget {
  const PublicProfileFacts({
    super.key,
    required this.workspace,
    this.compact = false,
  });

  final PublicWorkspace workspace;
  final bool compact;

  String _names(BuildContext context, List<String>? ids) =>
      ids == null || ids.isEmpty
      ? context.l10n.discoveryFieldNotPublished
      : ids.map((id) => publicFacetLabel(context.l10n, id)).join(', ');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final facts = [
      (
        id: 'amenities',
        label: l.publicPageFieldAmenities,
        value: _names(context, workspace.amenities),
      ),
      (
        id: 'accessibility',
        label: l.publicPageFieldAccessibility,
        value: _names(context, workspace.accessibility),
      ),
      (
        id: 'hours',
        label: l.publicPageFieldHours,
        value: publicOpeningHoursLine(context, workspace.openingHours),
      ),
    ];
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final fact in facts) Text(context.l10n.labelledValue(fact.label, fact.value)),
          if (workspace.takesInquiries == true)
            Text(l.publicProfileTakesInquiries),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.publicProfilePublishedInfo,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _section(
          context,
          'overview',
          l.publicProfileOverview,
          workspace.text('description'),
        ),
        for (final fact in facts)
          _section(
            context,
            fact.id,
            fact.label,
            fact.value,
            note: fact.id == 'hours' ? l.publicProfileRegularHours : null,
          ),
        if (workspace.text('plans').isNotEmpty)
          _section(
            context,
            'information',
            l.publicProfileInformation,
            workspace.text('plans'),
          ),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String id,
    String label,
    String value, {
    String? note,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: KitCard(
      key: ValueKey('public-profile-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            value.isEmpty ? context.l10n.discoveryFieldNotPublished : value,
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
}
