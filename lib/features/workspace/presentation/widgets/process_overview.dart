// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/process_status.dart';
import '../../domain/workspace_feature.dart';
import '../process_search.dart';
import 'feature_detail_sheet.dart';
import 'process_card.dart';
import 'process_change_sheet.dart';

/// The Features screen's primary view (#1327): one card per business
/// process instead of a hundred switches.
///
/// It reads the RAW stored feature set and nothing else. Every state it
/// shows comes from `processStatuses` (application/process_status.dart),
/// which consumes the #1326 resolver — this widget decides nothing about
/// dependencies. It writes nothing either: a tapped feature is handed to
/// [onOpenFeature], which shows it among the switches.
class ProcessOverview extends StatefulWidget {
  const ProcessOverview({
    super.key,
    required this.raw,
    required this.onOpenFeature,
  });

  final Set<WorkspaceFeature> raw;
  final ValueChanged<WorkspaceFeature> onOpenFeature;

  @override
  State<ProcessOverview> createState() => _ProcessOverviewState();
}

class _ProcessOverviewState extends State<ProcessOverview> {
  final _search = TextEditingController();
  String _query = '';
  ProcessFilter _filter = ProcessFilter.all;
  final _expanded = <String>{};

  /// Every card and subprocess row, so a search hit can bring its
  /// target on screen. The list is a plain column — nine cards — so
  /// every target is built and has a context to scroll to.
  final _keys = <String, GlobalKey>{};

  GlobalKey _keyFor(String key) => _keys[key] ??= GlobalKey();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// #1328 — a feature is explained first; the switch is one step further.
  void _explain(WorkspaceFeature feature) => showFeatureDetailSheet(
        context,
        feature: feature,
        raw: widget.raw,
        onChange: widget.onOpenFeature,
      );

  void _openHit(ProcessSearchHit hit) {
    if (hit.feature case final feature?) {
      _explain(feature);
      return;
    }
    setState(() {
      _search.clear();
      _query = '';
      _filter = ProcessFilter.all;
      _expanded.add(hit.processKey);
    });
    final target = _keyFor(hit.subprocessKey ?? hit.processKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = target.currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: motionDuration(targetContext, MotionTokens.standard),
        curve: MotionTokens.ease,
      );
    });
  }

  /// #1329 — the one preview-and-apply sheet; success is said only once
  /// the sheet came back with what the server confirmed.
  Future<void> _change(
    BuildContext context,
    String processKey,
    List<String> subprocessKeys,
    bool activate,
  ) async {
    final written = await showProcessChangeSheet(
      context,
      processKey: processKey,
      subprocessKeys: subprocessKeys,
      activate: activate,
    );
    if (written == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    AppSnack.success(
      context,
      l10n?.processApplied(written) ?? '$written features changed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statuses = processStatuses(widget.raw);
    final visible = {
      for (final status in statuses)
        if (status.matches(_filter)) status.process.key,
    };
    final hits = [
      for (final hit in searchProcesses(l10n, _query))
        if (visible.contains(hit.processKey)) hit,
    ];

    final Widget body;
    if (_query.isNotEmpty) {
      body = hits.isEmpty
          ? EmptyState(
              key: const ValueKey('process-no-match'),
              icon: Icons.search_off_outlined,
              title: l10n?.featuresNoMatch ?? 'No feature matches that.',
            )
          : ListView(
              key: const ValueKey('process-hits'),
              children: [
                for (final hit in hits) _HitTile(hit: hit, onTap: _openHit),
              ],
            );
    } else if (visible.isEmpty) {
      body = EmptyState(
        key: const ValueKey('process-filter-empty'),
        icon: Icons.filter_alt_off_outlined,
        title: l10n?.processFilterEmpty ?? 'No process matches this filter.',
      );
    } else {
      body = SingleChildScrollView(
        key: const ValueKey('process-cards'),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final status in statuses)
              if (visible.contains(status.process.key))
                KeyedSubtree(
                  key: _keyFor(status.process.key),
                  child: ProcessCard(
                    status: status,
                    expanded: _expanded.contains(status.process.key),
                    subprocessKeys: {
                      for (final sub in status.process.subprocesses)
                        sub.key: _keyFor(sub.key),
                    },
                    onToggle: () => setState(() {
                      final key = status.process.key;
                      if (!_expanded.remove(key)) _expanded.add(key);
                    }),
                    onOpenFeature: _explain,
                    onChange: (activate, keys) => _change(
                      context,
                      status.process.key,
                      keys,
                      activate,
                    ),
                  ),
                ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: TextField(
            key: const ValueKey('process-search'),
            controller: _search,
            onChanged: (value) => setState(() => _query = value.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              labelText:
                  l10n?.processSearchLabel ?? 'Search processes and features',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('process-search-clear'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        // A Wrap, not a scrolling row: four chips fit a phone on two
        // lines at worst, and nothing is ever cut at the edge.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final filter in ProcessFilter.values)
                ChoiceChip(
                  key: ValueKey('process-filter-${filter.name}'),
                  label: Text(_filterLabel(l10n, filter)),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  String _filterLabel(AppLocalizations? l10n, ProcessFilter filter) =>
      switch (filter) {
        ProcessFilter.all => l10n?.processFilterAll ?? 'All',
        ProcessFilter.active => processStateLabel(l10n, ProcessState.active),
        ProcessFilter.available => processStateLabel(
          l10n,
          ProcessState.available,
        ),
        ProcessFilter.needsAttention => processStateLabel(
          l10n,
          ProcessState.needsAttention,
        ),
      };
}

/// One search result, with the path above it (process › subprocess).
class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final ProcessSearchHit hit;
  final ValueChanged<ProcessSearchHit> onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('process-hit-${hit.kind.name}-${hit.id}'),
      contentPadding: EdgeInsets.only(
        left: AppSpacing.lg + AppSpacing.lg * hit.path.length,
        right: AppSpacing.lg,
      ),
      leading: Icon(switch (hit.kind) {
        ProcessHitKind.process => Icons.account_tree_outlined,
        ProcessHitKind.subprocess => Icons.subdirectory_arrow_right,
        ProcessHitKind.feature => Icons.tune,
      }),
      title: Text(hit.title),
      subtitle: hit.path.isEmpty ? null : Text(hit.path.join(' › ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onTap(hit),
    );
  }
}
