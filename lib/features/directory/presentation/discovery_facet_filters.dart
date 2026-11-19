// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2832 — Discover narrows by what businesses publish: facilities and
// accessibility, from the public contract's own catalogues, never from what
// the loaded results happen to contain. A business that publishes nothing
// about a fact is unknown for it, and a directory that cannot filter is said
// to have not been asked (the notice is the list's). The choice sits above
// the results, so it stays chosen while a listing loads, finds nothing or
// fails; "Clear filters" is always the way back.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_sheet.dart';
import '../domain/public_facets.dart';
import 'public_facet_labels.dart';

class DiscoveryFacetFilters extends StatelessWidget {
  const DiscoveryFacetFilters({
    required this.amenities,
    required this.accessibility,
    required this.onChanged,
    super.key,
  });

  /// The catalogue ids asked for.
  final List<String> amenities, accessibility;
  final void Function(List<String> amenities, List<String> accessibility)
  onChanged;

  int get _count => amenities.length + accessibility.length;

  Future<void> _open(BuildContext context) async {
    final chosen = await showAppSheet<(List<String>, List<String>)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FacetSheet(amenities: amenities, accessibility: accessibility),
    );
    if (chosen != null) onChanged(chosen.$1, chosen.$2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('directory-filters-open'),
              icon: const Icon(Icons.tune),
              label: Text(
                _count == 0
                    ? l10n.calendarFilters
                    : l10n.discoveryFiltersButtonCount(_count),
              ),
              onPressed: () => _open(context),
            ),
            for (final id in amenities)
              InputChip(
                key: ValueKey('directory-filter-chip-$id'),
                label: Text(publicFacetLabel(l10n, id)),
                onDeleted: () => onChanged(
                  [for (final a in amenities) if (a != id) a],
                  accessibility,
                ),
              ),
            for (final id in accessibility)
              InputChip(
                key: ValueKey('directory-filter-chip-$id'),
                label: Text(publicFacetLabel(l10n, id)),
                onDeleted: () => onChanged(
                  amenities,
                  [for (final a in accessibility) if (a != id) a],
                ),
              ),
            if (_count > 0)
              TextButton(
                key: const ValueKey('directory-filters-clear'),
                onPressed: () => onChanged(const [], const []),
                child: Text(l10n.discoveryFiltersClear),
              ),
          ],
        ),
      ),
    );
  }
}

class _FacetSheet extends StatefulWidget {
  const _FacetSheet({required this.amenities, required this.accessibility});

  final List<String> amenities, accessibility;

  @override
  State<_FacetSheet> createState() => _FacetSheetState();
}

class _FacetSheetState extends State<_FacetSheet> {
  late final _amenities = {...widget.amenities};
  late final _accessibility = {...widget.accessibility};

  Widget _group(
    String title,
    String field,
    Set<String> chosen,
    String keyPrefix,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final id in PublicFacets.ids(field))
              FilterChip(
                key: ValueKey('$keyPrefix-$id'),
                label: Text(publicFacetLabel(l10n, id)),
                selected: chosen.contains(id),
                onSelected: (on) => setState(() {
                  on ? chosen.add(id) : chosen.remove(id);
                }),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.discoveryFiltersTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _group(l10n.discoveryFiltersAmenities, 'amenities', _amenities, 'directory-facet-amenity'),
            const SizedBox(height: AppSpacing.md),
            _group(l10n.discoveryFiltersAccessibility, 'accessibility', _accessibility, 'directory-facet-access'),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.discoveryFiltersNote, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('directory-filters-show'),
              onPressed: () => Navigator.of(context).pop((
                [..._amenities],
                [..._accessibility],
              )),
              child: Text(l10n.discoveryFiltersShow),
            ),
          ],
        ),
      ),
    );
  }
}
