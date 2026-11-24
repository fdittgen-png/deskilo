// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/ui/form_kit.dart';
import '../domain/public_facets.dart';
import '../domain/public_workspace.dart';
import '../domain/publication_draft.dart';
import 'public_facet_labels.dart';

/// Only an edited field joins the patch; untouched unknown facts stay absent.
class PublicFacetsEditor extends StatelessWidget {
  const PublicFacetsEditor({
    super.key,
    required this.offer,
    required this.stored,
    required this.draft,
    required this.hoursController,
    required this.hasPlaces,
    required this.enabled,
  });
  final PublicWorkspace? offer;

  /// The page as read: a facet equal to it shows what [offer] reads.
  final PublicationDraft? stored;

  /// The owner's edits, from [stored].
  final ValueNotifier<PublicationDraft> draft;
  final TextEditingController hoursController;
  final bool hasPlaces, enabled;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: draft,
    builder: (context, edits, _) {
      final l = context.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: HelpDot(
              l.publicPageFieldAmenities,
              anchor: HelpAnchor.workspacePublicPage,
            ),
          ),
          for (final field in PublicFacets.fields)
            _choices(context, field, edits),
          _hours(context, edits),
        ],
      );
    },
  );

  Widget _choices(
    BuildContext context,
    String field,
    PublicationDraft edits,
  ) => FormSection(
    title: field == PublicFacets.amenities
        ? context.l10n.publicPageFieldAmenities
        : context.l10n.publicPageFieldAccessibility,
    children: [
      Text(context.l10n.publicPageFactsHelp),
      for (final id in PublicFacets.ids(field))
        CheckboxListTile(
          key: ValueKey('public-facet-$field-$id'),
          title: Text(publicFacetLabel(context.l10n, id)),
          value: _selected(field, edits).contains(id),
          onChanged: !enabled
              ? null
              : (selected) {
                  final values = _selected(field, edits).toSet();
                  if (selected == true) {
                    values.add(id);
                  } else {
                    values.remove(id);
                  }
                  draft.value = edits.withFacet(field, [
                    for (final value in PublicFacets.ids(field))
                      if (values.contains(value)) value,
                  ]);
                },
        ),
    ],
  );

  Widget _hours(BuildContext context, PublicationDraft edits) =>
      FormSection(
        title: context.l10n.publicPageFieldHours,
        children: [
          if (hasPlaces) ...[
            Text(context.l10n.publicPageHoursFollow),
            Text(
              publicOpeningHoursLine(context, offer?.openingHours),
              key: const ValueKey('public-hours-followed'),
            ),
            TextButton(
              key: const ValueKey('public-hours-edit-availability'),
              onPressed: !enabled ? null : () => context.push(Routes.availability),
              child: Text(context.l10n.publicPageHoursEdit),
            ),
          ] else
            AppTextField(
              key: const ValueKey('public-hours-note'),
              controller: hoursController,
              label: context.l10n.publicPageFieldHours,
              helper: context.l10n.publicPageHoursNoteHelp,
              maxLength: 4000,
              maxLines: 3,
              enabled: enabled,
              onChanged: (value) =>
                  draft.value = edits.copyWith(hoursNote: value),
            ),
        ],
      );

  List<String> _selected(String field, PublicationDraft edits) {
    final read = stored;
    if (read == null || edits.facetDiffers(read, field)) {
      return PublicFacets.read(field, edits.facet(field)) ?? const [];
    }
    return (field == PublicFacets.amenities
            ? offer?.amenities
            : offer?.accessibility) ??
        const [];
  }
}
