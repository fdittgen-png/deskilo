// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — the one analysis toolbar of the Web-BI page. Every module
// reads the same context; an option no visible module can answer is
// shown disabled with its reason, never offered and then ignored.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';

/// The period's name: "March 2026", "Q1 2026", "2026".
String biPeriodLabel(BiPeriod p, AppLocalizations l10n, String locale) =>
    switch (p.grain) {
      BiGrain.month => DateFormat.yMMMM(
        locale,
      ).format(DateTime(p.year, p.index)),
      BiGrain.quarter =>
        l10n.biQuarter('${p.index}', '${p.year}'),
      BiGrain.year => '${p.year}',
    };

String biDimensionName(AppLocalizations l10n, String dimension) =>
    switch (dimension) {
      'level' => l10n.biDimensionLevel,
      _ => dimension,
    };

class BiToolbar extends StatelessWidget {
  const BiToolbar({
    super.key,
    required this.query,
    required this.modules,
    required this.today,
    required this.onChanged,
    this.cardTitle,
  });

  final BiQueryContext query;

  /// The modules on the page: an option none of them supports is
  /// disabled with its reason.
  final List<BiModule> modules;

  /// The workspace date relative periods resolve against.
  final DateTime today;
  final ValueChanged<BiQueryContext> onChanged;

  /// A module's display name, for the analyses dialog.
  final String Function(String moduleId)? cardTitle;

  DropdownMenuItem<T> _item<T>(
    BuildContext context,
    T value,
    String label, {
    required bool supported,
  }) =>
      DropdownMenuItem<T>(
        value: value,
        enabled: supported,
        child: Text(
          supported ? label : '$label — ${context.l10n.biNotOffered}',
        ),
      );

  Widget _field<T>({
    required String fieldKey,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onSelected,
    bool enabled = true,
  }) =>
      SizedBox(

    width: 200,
    // A stateless dropdown: the value is the address's, so Back and a
    // reload show what is asked, never a field's stale selection.
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        enabled: enabled,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: ValueKey('bi-$fieldKey'),
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: enabled
              ? (v) {
                  if (v != null && v != value) onSelected(v);
                }
              : null,
        ),
      ),
    ),
  );

  Widget _stepper(
    BuildContext context,
    String keyName,
    BiPeriod p,
    ValueChanged<int> shift,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final material = MaterialLocalizations.of(context);
    return Row(

      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('bi-$keyName-previous'),
          tooltip: material.previousPageTooltip,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => shift(-1),
        ),
        Text(
          biPeriodLabel(p, l10n, locale),
          key: ValueKey('bi-$keyName-label'),
        ),
        IconButton(
          key: ValueKey('bi-$keyName-next'),
          tooltip: material.nextPageTooltip,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => shift(1),
        ),
      ],
    );
  }

  Future<void> _chooseCards(BuildContext context) async {
        final chosen = await showDialog<List<String>>(
          context: context,
          builder: (_) => _CardsDialog(
            modules: modules,
            shown: query.cards.isEmpty
                ? [for (final m in modules) m.id]
                : [
                    for (final c in query.cards)
                      if (modules.any((m) => m.id == c)) c,
                  ],
            title: cardTitle,
          ),
        );
        if (chosen == null || chosen.isEmpty) return;
        final all = [for (final m in modules) m.id];
        // Every analysis in the standard order is the standard.
        final standard =
            chosen.length == all.length &&
            [for (var i = 0; i < all.length; i++) all[i] == chosen[i]]
                .every((same) => same);
        onChanged(query.copyWith(cards: standard ? const [] : chosen));
  }

  Widget _viewSwitch(AppLocalizations l10n) {
    return SegmentedButton<BiView>(
  key: const ValueKey('bi-view'),
  segments: [
    ButtonSegment(
      value: BiView.dashboard,
      icon: const Icon(Icons.space_dashboard_outlined),
      label: Text(l10n.biViewDashboard),
    ),
    ButtonSegment(
      value: BiView.table,
      icon: const Icon(Icons.table_rows_outlined),
      label: Text(l10n.biViewTable),
    ),
    ButtonSegment(
      value: BiView.chart,
      icon: const Icon(Icons.bar_chart),
      label: Text(l10n.biViewChart),
    ),
  ],
  selected: {query.view},
  onSelectionChanged: (v) => onChanged(query.copyWith(view: v.first)),
);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = query.current(today);

    final grouped = query.groupBy != null;
    final compared = query.compared(today);
    return Padding(
      padding: AppSpacing.mdAll,
      child: Wrap(
        key: const ValueKey('bi-toolbar'),
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _field<BiGrain>(
            fieldKey: 'grain',
            label: l10n.biGrain,
            value: query.grain,
            items: [
              for (final g in BiGrain.values)
                _item(context, g, switch (g) {
                  BiGrain.month => l10n.biGrainMonth,
                  BiGrain.quarter => l10n.biGrainQuarter,
                  BiGrain.year => l10n.biGrainYear,
                }, supported: modules.any((m) => m.grains.contains(g))),
            ],
            onSelected: (g) => onChanged(query.copyWith(grain: g)),
          ),
          _stepper(
            context,
            'period',
            current,
            (by) => onChanged(
              query.copyWith(
                period: query.period.isRelative
                    ? BiPeriodRef.relative(query.period.offset! + by)
                    : BiPeriodRef.fixed(current.shift(by)),
              ),
            ),
          ),
          _field<BiComparison>(
            fieldKey: 'comparison',
            label: l10n.biCompare,
            value: query.comparison,
            items: [
              for (final c in BiComparison.values)
                _item(context, c, switch (c) {
                  BiComparison.none => l10n.biCompareNone,
                  BiComparison.previousPeriod =>
                    l10n.biComparePrevious,
                  BiComparison.previousYear =>
                    l10n.biComparePreviousYear,
                  BiComparison.custom =>
                    l10n.biCompareCustom,
                }, supported: modules.any((m) => m.comparisons.contains(c))),
            ],
            onSelected: (c) => onChanged(
              query.copyWith(
                comparison: c,
                comparedWith: c == BiComparison.custom
                    ? current.shift(-1)
                    : null,
              ),
            ),
          ),
          if (query.comparison == BiComparison.custom && compared != null)
            _stepper(
              context,
              'compared',
              compared,
              (by) =>
                  onChanged(query.copyWith(comparedWith: compared.shift(by))),
            ),
          _field<String>(
            fieldKey: 'group',
            label: l10n.biGroupBy,
            value: query.groupBy ?? '',
            items: [
              _item(context, '', l10n.biGroupNone, supported: true),
              for (final d in biDimensions)
                _item(context, 
                  d,
                  biDimensionName(l10n, d),
                  supported: modules.any((m) => m.groupings.contains(d)),
                ),
            ],
            onSelected: (d) => onChanged(
              d.isEmpty
                  ? query.copyWith(clearGroupBy: true)
                  : query.copyWith(groupBy: d),
            ),
          ),
          _field<BiSort>(
            fieldKey: 'sort',
            label: grouped
                ? l10n.biSort
                : l10n.biSortUngrouped,
            value: query.sort,
            enabled: grouped,
            items: [
              for (final s in BiSort.values)
                _item(context, s, switch (s) {
                  BiSort.natural => l10n.biSortNatural,
                  BiSort.valueDescending =>
                    l10n.biSortDescending,
                  BiSort.valueAscending =>
                    l10n.biSortAscending,
                }, supported: true),
            ],
            onSelected: (s) => onChanged(query.copyWith(sort: s)),
          ),
          if (modules.length > 1)
            OutlinedButton.icon(
              key: const ValueKey('bi-cards'),
              icon: const Icon(Icons.view_agenda_outlined),
              label: Text(l10n.biCards),
              onPressed: () => _chooseCards(context),
            ),
          _viewSwitch(l10n),
        ],
      ),
    );
  }
}

/// Which analyses the page shows, and in which order (#1923 C, #1924).
class _CardsDialog extends StatefulWidget {
  const _CardsDialog({
    required this.modules,
    required this.shown,
    required this.title,
  });

  final List<BiModule> modules;
  final List<String> shown;
  final String Function(String moduleId)? title;

  @override
  State<_CardsDialog> createState() => _CardsDialogState();
}

class _CardsDialogState extends State<_CardsDialog> {
  late final List<String> _order = [
    ...widget.shown,
    for (final m in widget.modules)
      if (!widget.shown.contains(m.id)) m.id,
  ];
  late final Set<String> _on = {...widget.shown};

  void _move(int i, int by) => setState(() {
    final id = _order.removeAt(i);
    _order.insert(i + by, id);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.biCards),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (i, id) in _order.indexed)
              CheckboxListTile(
                key: ValueKey('bi-card-$id'),
                value: _on.contains(id),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(widget.title?.call(id) ?? id),
                onChanged: (v) =>
                    setState(() => v == true ? _on.add(id) : _on.remove(id)),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('bi-card-up-$id'),
                      tooltip: l10n.biCardUp,
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0 ? null : () => _move(i, -1),
                    ),
                    IconButton(
                      key: ValueKey('bi-card-down-$id'),
                      tooltip: l10n.biCardDown,
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == _order.length - 1
                          ? null
                          : () => _move(i, 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bi-toolbar-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey('bi-cards-ok'),
          // At least one analysis: an empty page is not a view.
          onPressed: _on.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                  for (final id in _order)
                    if (_on.contains(id)) id,
                ]),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}
