// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #842 — choosing what a message points at.
//
// Both original pickers were flat, unfiltered lists: seven days of every
// reservation in the workspace, every seat of a level. That is fine with
// four members and unusable with forty — the thing you want is somewhere
// in a list you have to scroll past. One sheet now serves every kind of
// reference, it filters as you type, and it says how much of the list
// you are looking at, so an empty result reads as "your words matched
// nothing" instead of "there is nothing here".
//
// A long list of invoices, payments or alerts also carries FACETS (status,
// person, month, amount, workspace): the sheet then offers one-tap chips for
// the main one, an advanced panel for the rest, a sort, and groups the rows
// by month. A list without facets behaves exactly as before.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../l10n/app_localizations.dart';
import 'ref_picker_filter.dart';
import 'ref_picker_filters_panel.dart';

export 'ref_picker_filter.dart'
    show RefFacet, RefFacetValue, RefFilter, RefSort;

/// One choosable target. [keywords] is what the filter matches on, so a
/// row can be findable by more than the words it shows.
class RefCandidate implements RefFilterable {
  const RefCandidate({
    required this.id,
    required this.label,
    this.detail,
    required this.icon,
    required this.keywords,
    this.facets = const {},
    this.amountCents,
    this.at,
  });

  final String id;
  final String label;
  final String? detail;
  final IconData icon;
  @override
  final String keywords;

  /// facet key → this candidate's value (for the filters).
  @override
  final Map<String, RefFacetValue> facets;
  @override
  final int? amountCents;

  /// When it happened — the sort and the month headers.
  @override
  final DateTime? at;
}

/// Builds a candidate whose searchable text is its own label and detail.
RefCandidate refCandidate({
  required String id,
  required String label,
  String? detail,
  required IconData icon,
  String extraKeywords = '',
  Map<String, RefFacetValue> facets = const {},
  int? amountCents,
  DateTime? at,
}) => RefCandidate(
  id: id,
  label: label,
  detail: detail,
  icon: icon,
  keywords: '$label ${detail ?? ''} $extraKeywords'.toLowerCase(),
  facets: facets,
  amountCents: amountCents,
  at: at,
);

/// Asks which of [candidates] the message should point at. Returns the
/// chosen id, or null when the sheet is dismissed.
///
/// [facets] name the dimensions the candidates carry; [formatAmount] writes
/// an amount for the range filter.
Future<String?> showRefPicker(
  BuildContext context, {
  required String title,
  required List<RefCandidate> candidates,
  required String keyPrefix,
  List<RefFacet> facets = const [],
  String Function(int cents)? formatAmount,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.92,
  ),
  builder: (_) => _RefPickerSheet(
    title: title,
    candidates: candidates,
    keyPrefix: keyPrefix,
    facets: facets,
    formatAmount: formatAmount,
  ),
);

class _RefPickerSheet extends StatefulWidget {
  const _RefPickerSheet({
    required this.title,
    required this.candidates,
    required this.keyPrefix,
    required this.facets,
    required this.formatAmount,
  });

  final String title;
  final List<RefCandidate> candidates;
  final String keyPrefix;
  final List<RefFacet> facets;
  final String Function(int cents)? formatAmount;

  @override
  State<_RefPickerSheet> createState() => _RefPickerSheetState();
}

class _RefPickerSheetState extends State<_RefPickerSheet> {
  RefFilter _filter = const RefFilter();

  RefFacet? get _quick => widget.facets.where((f) => f.quick).firstOrNull;

  bool get _hasAdvanced =>
      widget.facets.isNotEmpty || refAmountBounds(widget.candidates) != null;

  String _sortLabel(AppLocalizations? l10n, RefSort sort) => switch (sort) {
    RefSort.newest => l10n?.refSortNewest ?? 'Newest first',
    RefSort.oldest => l10n?.refSortOldest ?? 'Oldest first',
    RefSort.amountHigh => l10n?.refSortAmountHigh ?? 'Highest amount',
    RefSort.amountLow => l10n?.refSortAmountLow ?? 'Lowest amount',
  };

  Future<void> _openAdvanced() async {
    final next = await showRefFiltersPanel(
      context,
      keyPrefix: widget.keyPrefix,
      all: widget.candidates,
      facets: widget.facets,
      initial: _filter,
      formatAmount: widget.formatAmount,
    );
    if (next != null && mounted) setState(() => _filter = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visible = applyRefFilter(widget.candidates, _filter);
    // The filter earns its place only on a list long enough to hide
    // things; below that it is one more thing to look past.
    final filterable = widget.candidates.length > 6;
    final quick = filterable ? _quick : null;
    final sortable =
        filterable &&
        widget.candidates.any((c) => c.at != null || c.amountCents != null);
    // Month headers only while the order is by date.
    final grouped =
        (_filter.sort == RefSort.newest || _filter.sort == RefSort.oldest) &&
        visible.any((c) => c.at != null);
    final locale = Localizations.maybeLocaleOf(context)?.toString();

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
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            if (filterable)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('${widget.keyPrefix}-filter'),
                        autofocus: false,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          labelText: l10n?.noteRefFilterLabel ?? 'Filter',
                          helperText:
                              l10n?.noteRefFilterCount(
                                visible.length,
                                widget.candidates.length,
                              ) ??
                              '${visible.length} of ${widget.candidates.length}',
                        ),
                        onChanged: (value) => setState(
                          () => _filter = _filter.copyWith(query: value),
                        ),
                      ),
                    ),
                    if (_hasAdvanced) ...[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        key: Key('${widget.keyPrefix}-more'),
                        tooltip: l10n?.refFilterMore ?? 'Filters',
                        onPressed: _openAdvanced,
                        icon: _filter.activeCount > 0
                            ? Badge.count(
                                count: _filter.activeCount,
                                child: const Icon(Icons.tune),
                              )
                            : const Icon(Icons.tune),
                      ),
                    ],
                  ],
                ),
              ),
            if (quick != null)
              _QuickChips(
                key: Key('${widget.keyPrefix}-quick'),
                keyPrefix: widget.keyPrefix,
                facet: quick,
                all: widget.candidates,
                filter: _filter,
                onChanged: (next) => setState(() => _filter = next),
              ),
            if (_filter.activeCount > 0)
              _ActiveChips(
                key: Key('${widget.keyPrefix}-active'),
                keyPrefix: widget.keyPrefix,
                facets: widget.facets,
                all: widget.candidates,
                filter: _filter,
                skip: quick?.key,
                formatAmount: widget.formatAmount,
                onChanged: (next) => setState(() => _filter = next),
              ),
            if (filterable && (sortable || !_filter.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    if (sortable)
                      PopupMenuButton<RefSort>(
                        key: Key('${widget.keyPrefix}-sort'),
                        tooltip: l10n?.refFilterSort ?? 'Sort',
                        initialValue: _filter.sort,
                        onSelected: (s) =>
                            setState(() => _filter = _filter.copyWith(sort: s)),
                        itemBuilder: (_) => [
                          for (final s in RefSort.values)
                            PopupMenuItem(
                              value: s,
                              child: Text(_sortLabel(l10n, s)),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_vert, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(l10n, _filter.sort),
                                style: theme.textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (!_filter.isEmpty)
                      TextButton(
                        key: Key('${widget.keyPrefix}-clear'),
                        onPressed: () => setState(
                          () => _filter = RefFilter(sort: _filter.sort),
                        ),
                        child: Text(l10n?.refFilterClear ?? 'Clear filters'),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        l10n?.noteRefFilterEmpty ?? 'Nothing matches.',
                        key: Key('${widget.keyPrefix}-empty'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (var i = 0; i < visible.length; i++) ...[
                          if (grouped && _startsMonth(visible, i))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                0,
                              ),
                              child: Text(
                                visible[i].at == null
                                    ? ''
                                    : DateFormat.yMMMM(locale)
                                          .format(visible[i].at!),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ListTile(
                            key: Key('${widget.keyPrefix}-${visible[i].id}'),
                            leading: Icon(visible[i].icon),
                            title: Text(visible[i].label),
                            subtitle: visible[i].detail == null
                                ? null
                                : Text(visible[i].detail!),
                            onTap: () =>
                                Navigator.of(context).pop(visible[i].id),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _startsMonth(List<RefCandidate> rows, int i) {
    final at = rows[i].at;
    if (at == null) return false;
    if (i == 0) return true;
    final before = rows[i - 1].at;
    return before == null || before.year != at.year || before.month != at.month;
  }
}

/// "All · Open · Paid …": one tap narrows by the main facet, each chip with
/// the count it would leave.
class _QuickChips extends StatelessWidget {
  const _QuickChips({
    super.key,
    required this.keyPrefix,
    required this.facet,
    required this.all,
    required this.filter,
    required this.onChanged,
  });

  final String keyPrefix;
  final RefFacet facet;
  final List<RefCandidate> all;
  final RefFilter filter;
  final ValueChanged<RefFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = refFacetOptions(all, filter, facet.key);
    if (options.length < 2 &&
        (filter.selected[facet.key] ?? const {}).isEmpty) {
      return const SizedBox.shrink();
    }
    final chosen = filter.selected[facet.key] ?? const <String>{};
    final total = applyRefFilter(all, filter, ignoreFacet: facet.key).length;
    return SizedBox(
      height: 48,
      child: EdgeFadeScroll.around(
        builder: (context, controller) => ListView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('$keyPrefix-quick-all'),
                label: Text('${l10n?.refFilterAll ?? 'All'} · $total'),
                selected: chosen.isEmpty,
                onSelected: (_) => onChanged(filter.cleared(facet.key)),
              ),
            ),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('$keyPrefix-quick-${o.value.id}'),
                  label: Text('${o.value.label} · ${o.count}'),
                  selected: chosen.contains(o.value.id),
                  onSelected: (_) =>
                      onChanged(filter.toggled(facet, o.value.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The advanced choices that are on, each removable with one tap.
class _ActiveChips extends StatelessWidget {
  const _ActiveChips({
    super.key,
    required this.keyPrefix,
    required this.facets,
    required this.all,
    required this.filter,
    required this.skip,
    required this.formatAmount,
    required this.onChanged,
  });

  final String keyPrefix;
  final List<RefFacet> facets;
  final List<RefCandidate> all;
  final RefFilter filter;
  final String? skip;
  final String Function(int cents)? formatAmount;
  final ValueChanged<RefFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chips = <Widget>[];
    for (final facet in facets) {
      if (facet.key == skip) continue;
      final chosen = filter.selected[facet.key] ?? const <String>{};
      if (chosen.isEmpty) continue;
      final options = refFacetOptions(all, filter, facet.key);
      for (final id in chosen) {
        final label =
            options.where((o) => o.value.id == id).firstOrNull?.value.label ??
            id;
        chips.add(
          InputChip(
            key: Key('$keyPrefix-active-${facet.key}-$id'),
            label: Text(label),
            onDeleted: () => onChanged(filter.toggled(facet, id)),
          ),
        );
      }
    }
    if (filter.hasAmount) {
      final fmt = formatAmount ?? (c) => (c / 100).toStringAsFixed(2);
      final lo = filter.minCents == null ? '' : fmt(filter.minCents!);
      final hi = filter.maxCents == null ? '' : fmt(filter.maxCents!);
      chips.add(
        InputChip(
          key: Key('$keyPrefix-active-amount'),
          avatar: const Icon(Icons.payments_outlined, size: 18),
          label: Text('${l10n?.refFilterAmount ?? 'Amount'} $lo – $hi'),
          onDeleted: () => onChanged(filter.copyWith(clearAmount: true)),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }
}
