// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/template_compare.dart';
import '../../domain/template_capabilities.dart';
import '../../domain/template_inspection.dart';
import '../../domain/workspace_template.dart';

/// #1660 — up to four shortlisted templates, side by side, from their
/// inspected settings (#1655/#1659): every field, not only what is on.
/// A value missing from a template is shown as missing, never as false;
/// money in different currencies is marked as not comparable. On a
/// narrow screen a baseline is compared with one chosen alternative,
/// from the same rows. Read-only: nothing here applies anything.
class TemplateCompareScreen extends ConsumerStatefulWidget {
  const TemplateCompareScreen({super.key, required this.templates});

  final List<WorkspaceTemplate> templates;

  @override
  ConsumerState<TemplateCompareScreen> createState() =>
      _TemplateCompareScreenState();
}

class _TemplateCompareScreenState extends ConsumerState<TemplateCompareScreen> {
  bool _differencesOnly = true;
  String _filter = '';
  int _baseline = 0;
  int _other = 1;

  static const wideWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = widget.templates.map((t) => t.id).join(',');
    final comparison = ref.watch(templateComparisonProvider(ids));
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.compareTitle ?? 'Compare templates')),
      body: comparison.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(
          padding: AppSpacing.gutterAll,
          child: InlineBanner(
            key: const ValueKey('compare-unavailable'),
            icon: Icons.cloud_off_outlined,
            severity: InlineBannerSeverity.error,
            text: l10n?.compareUnavailable ?? 'These templates could not be read to compare them. Nothing is claimed either way.',
          ),
        ),
        data: (rows) => LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= wideWidth;
            final columns = wide
                ? [for (var i = 0; i < widget.templates.length; i++) i]
                : [_baseline, _other.clamp(0, widget.templates.length - 1)];
            final shown = [
              for (final r in rows)
                if ((!_differencesOnly ||
                        r.difference != ComparisonDifference.same) &&
                    (_filter.isEmpty || r.path.toLowerCase().contains(_filter)))
                  r,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: AppSpacing.gutterAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        key: const ValueKey('compare-mode'),
                        segments: [
                          ButtonSegment(
                            value: true,
                            label: Text(
                              l10n?.compareDifferences ?? 'Differences',
                            ),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text(l10n?.compareAll ?? 'All settings'),
                          ),
                        ],
                        selected: {_differencesOnly},
                        onSelectionChanged: (v) =>
                            setState(() => _differencesOnly = v.first),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        key: const ValueKey('compare-search'),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n?.compareSearch ?? 'Find a setting',
                        ),
                        onChanged: (v) =>
                            setState(() => _filter = v.trim().toLowerCase()),
                      ),
                      if (!wide && widget.templates.length > 2) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _picker(
                                key: 'compare-baseline',
                                value: _baseline,
                                onChanged: (i) => setState(() => _baseline = i),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _picker(
                                key: 'compare-other',
                                value: _other,
                                onChanged: (i) => setState(() => _other = i),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n?.compareCount(
                              '${shown.length}',
                              '${rows.length}',
                            ) ??
                            '${shown.length} of ${rows.length} settings',
                        key: const ValueKey('compare-count'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _header(context, columns),
                const Divider(height: 1),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text(
                            l10n?.compareNothing ?? 'No setting differs.',
                          ),
                        )
                      : ListView.separated(
                          key: const ValueKey('compare-rows'),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) =>
                              _row(context, l10n, shown[i], columns),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _picker({
    required String key,
    required int value,
    required ValueChanged<int> onChanged,
  }) => DropdownButton<int>(
    key: ValueKey(key),
    isExpanded: true,
    value: value,
    items: [
      for (var i = 0; i < widget.templates.length; i++)
        DropdownMenuItem(
          value: i,
          child: Text(
            widget.templates[i].name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (v) => v == null ? null : onChanged(v),
  );

  Widget _header(BuildContext context, List<int> columns) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: [
        const Expanded(flex: 3, child: SizedBox.shrink()),
        for (final c in columns)
          Expanded(
            flex: 2,
            child: Text(
              widget.templates[c].name,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );

  Widget _row(
    BuildContext context,
    AppLocalizations? l10n,
    ComparisonRow r,
    List<int> columns,
  ) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('compare-row-${r.path}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.path, style: theme.textTheme.bodyMedium),
                if (r.difference == ComparisonDifference.notComparable)
                  Text(
                    l10n?.compareCurrencies ??
                        'Different currencies: not comparable',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          for (final c in columns)
            Expanded(
              flex: 2,
              child: Text(
                comparisonCellText(l10n, r.cells[c]),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// A cell in words: its value, or why there is none — never "false"
/// for something the template does not say.
String comparisonCellText(AppLocalizations? l10n, ComparisonCell c) =>
    switch (c.disposition) {
      TemplateFieldDisposition.present => switch (c.value) {
        true => l10n?.compareYes ?? 'Yes',
        false => l10n?.compareNo ?? 'No',
        null => '—',
        final List<Object?> list => list.join(', '),
        final v => '$v',
      },
      TemplateFieldDisposition.absent => switch (c.absent) {
        TemplateAbsentMeaning.inherit =>
          l10n?.compareInherits ?? 'Keeps the space\'s own',
        TemplateAbsentMeaning.productDefault ||
        TemplateAbsentMeaning.registryDefault =>
          l10n?.compareDefault ?? 'Default',
        TemplateAbsentMeaning.required => l10n?.compareLocal ?? 'Set locally',
        _ => l10n?.compareMissing ?? 'Not in this template',
      },
      TemplateFieldDisposition.unknown => l10n?.compareUnknown ?? 'Unknown',
      _ => l10n?.compareNotCarried ?? 'Not carried',
    };
