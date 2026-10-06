// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The advanced panel of the reference picker: every facet as chips with the
// count each would leave, a person search when there are many, an amount
// range, and a button that says how many results the choices give.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'ref_picker_filter.dart';

/// Shows the panel; returns the filter the person settled on, or null when
/// it was dismissed.
Future<RefFilter?> showRefFiltersPanel<T extends RefFilterable>(
  BuildContext context, {
  required String keyPrefix,
  required List<T> all,
  required List<RefFacet> facets,
  required RefFilter initial,
  String Function(int cents)? formatAmount,
}) => showModalBottomSheet<RefFilter>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.92,
  ),
  builder: (_) => _Panel<T>(
    keyPrefix: keyPrefix,
    all: all,
    facets: facets,
    initial: initial,
    formatAmount: formatAmount,
  ),
);

class _Panel<T extends RefFilterable> extends StatefulWidget {
  const _Panel({
    required this.keyPrefix,
    required this.all,
    required this.facets,
    required this.initial,
    required this.formatAmount,
  });

  final String keyPrefix;
  final List<T> all;
  final List<RefFacet> facets;
  final RefFilter initial;
  final String Function(int cents)? formatAmount;

  @override
  State<_Panel<T>> createState() => _PanelState<T>();
}

class _PanelState<T extends RefFilterable> extends State<_Panel<T>> {
  late RefFilter _filter = widget.initial;
  final Map<String, String> _search = {};

  /// More options than this get a small search box of their own.
  static const _searchableFrom = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = applyRefFilter(widget.all, _filter).length;
    final bounds = refAmountBounds(widget.all);
    final fmt = widget.formatAmount ?? (int c) => (c / 100).toStringAsFixed(2);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.refFilterMore ?? 'Filters',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    key: Key('${widget.keyPrefix}-reset'),
                    onPressed: _filter.activeCount == 0
                        ? null
                        : () => setState(
                            () => _filter = RefFilter(
                              query: _filter.query,
                              sort: _filter.sort,
                            ),
                          ),
                    child: Text(l10n?.refFilterReset ?? 'Reset'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final facet in widget.facets)
                    _facetSection(context, facet),
                  if (bounds != null && bounds.max > bounds.min)
                    _amountSection(context, bounds, fmt),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: Key('${widget.keyPrefix}-apply'),
                  onPressed: () => Navigator.of(context).pop(_filter),
                  child: Text(
                    l10n?.refFilterShow(shown) ?? 'Show $shown results',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _facetSection(BuildContext context, RefFacet facet) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    var options = refFacetOptions(widget.all, _filter, facet.key);
    if (options.isEmpty) return const SizedBox.shrink();
    // Months and the like read best newest first; names alphabetically.
    options.sort(
      (a, b) => facet.key == 'month'
          ? b.value.id.compareTo(a.value.id)
          : a.value.label.toLowerCase().compareTo(b.value.label.toLowerCase()),
    );
    final needle = (_search[facet.key] ?? '').toLowerCase();
    if (needle.isNotEmpty) {
      options = [
        for (final o in options)
          if (o.value.label.toLowerCase().contains(needle)) o,
      ];
    }
    final chosen = _filter.selected[facet.key] ?? const <String>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facet.label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          if (refFacetOptions(widget.all, _filter, facet.key).length >=
              _searchableFrom)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextField(
                key: Key('${widget.keyPrefix}-facet-${facet.key}-search'),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: const OutlineInputBorder(),
                  hintText: l10n?.refFilterFindIn(facet.label) ?? facet.label,
                ),
                onChanged: (v) => setState(() => _search[facet.key] = v),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final o in options)
                FilterChip(
                  key: Key(
                    '${widget.keyPrefix}-facet-${facet.key}-${o.value.id}',
                  ),
                  label: Text('${o.value.label} · ${o.count}'),
                  selected: chosen.contains(o.value.id),
                  onSelected: (_) => setState(
                    () => _filter = _filter.toggled(facet, o.value.id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountSection(
    BuildContext context,
    ({int min, int max}) bounds,
    String Function(int) fmt,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lo = (_filter.minCents ?? bounds.min).clamp(bounds.min, bounds.max);
    final hi = (_filter.maxCents ?? bounds.max).clamp(bounds.min, bounds.max);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.refFilterAmount ?? 'Amount',
            style: theme.textTheme.titleSmall,
          ),
          RangeSlider(
            key: Key('${widget.keyPrefix}-amount'),
            min: bounds.min.toDouble(),
            max: bounds.max.toDouble(),
            values: RangeValues(lo.toDouble(), hi.toDouble()),
            labels: RangeLabels(fmt(lo), fmt(hi)),
            onChanged: (v) => setState(() {
              final start = v.start.round();
              final end = v.end.round();
              // At the ends the bound is "no limit": the filter is off.
              _filter = start <= bounds.min && end >= bounds.max
                  ? _filter.copyWith(clearAmount: true)
                  : RefFilter(
                      query: _filter.query,
                      selected: _filter.selected,
                      sort: _filter.sort,
                      minCents: start,
                      maxCents: end,
                    );
            }),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(fmt(lo)), Text(fmt(hi))],
          ),
        ],
      ),
    );
  }
}
