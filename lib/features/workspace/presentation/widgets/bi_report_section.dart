// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — the report designer on the Web-BI page: "Duplicate as report"
// (the analysis on screen, or the open report, becomes a private report)
// and, for an open report the reader may change, its editor. Both exist only
// while `biReportDesigner` is on; reading a saved report — its pages among
// them — never needs it. A team report is changed by someone who may share
// views (workspaceSettings or designDocuments); a report holding figures this
// reader may not read is never edited by them (the server withheld those
// figures), only copied.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_saved_view.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../report_editor/bi_report_editor_screen.dart' show biReportEditable;
import 'bi_report_panel.dart';
import 'bi_report_parts.dart';
import 'bi_view_failure_text.dart';
import 'bi_views_bar.dart' show BiOpenView, biCanShareViews;

class BiReportSection extends ConsumerWidget {
  const BiReportSection({
    super.key,
    required this.workspaceId,
    required this.query,
    required this.openId,
    required this.visibleModules,
    required this.onOpen,
  });

  final String workspaceId;
  final BiQueryContext query;

  /// The `saved` address parameter: a view id, or null.
  final String? openId;

  /// The module ids this reader may see now.
  final Set<String> visibleModules;
  final BiOpenView onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (visibleModules.isEmpty) return const SizedBox.shrink();
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.biReportDesigner);
    final views = ref.watch(biViewsProvider(workspaceId)).value ?? const [];
    final open = views.where((v) => v.id == openId).firstOrNull;
    final report = open?.definition?.report;
    final canShare = biCanShareViews(ref.watch(myPermissionsProvider));
    final editing = on && open != null && biReportEditable(open, canShare: canShare)
        ? open
        : null;
    final page = report == null ? 0 : _pageOf(report);
    void openPage(BiSavedView view, int index) {
      final q = view.definition?.report?.queryOfPage(index);
      if (q != null) onOpen(view, q);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (on)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextButton.icon(
              key: const ValueKey('bi-views-duplicate-report'),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: Text(context.l10n.biReportDuplicate),
              onPressed: () => _duplicate(context, ref, open),
            ),
          ),
        if (editing != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextButton.icon(
              key: const ValueKey('bi-report-open-editor'),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.biEditorOpen),
              // push: Back (and the editor's Close) return to this page.
              onPressed: () => context.push('/bi/report/${editing.id}'),
            ),
          ),
        if (editing != null)
          BiReportPanel(
            key: ValueKey('bi-report-panel-${editing.id}'),
            workspaceId: workspaceId,
            view: editing,
            pageIndex: page,
            visibleModules: visibleModules,
            onPage: openPage,
          )
        else if (open != null && report != null && report.pages.length > 1)
          BiReportPages(
            key: const ValueKey('bi-report-pages'),
            report: report,
            selected: page,
            visibleModules: visibleModules,
            onSelected: (i) => openPage(open, i),
          ),
      ],
    );
  }

  /// The page the address shows: the first whose cards are the query's.
  int _pageOf(BiReportDefinition report) {
    for (final (i, p) in report.pages.indexed) {
      final cards = BiReportDefinition.cardsOf(p);
      if (cards.length == query.cards.length &&
          cards.indexed.every((e) => query.cards[e.$1] == e.$2)) {
        return i;
      }
    }
    return 0;
  }

  /// A report copies as it is, as the reader's own private report (never a
  /// shared overwrite); a question becomes one page of cards, in the order
  /// it shows them.
  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    BiSavedView? open,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cards = query.cards.isEmpty
        ? [
            for (final m in biModules)
              if (visibleModules.contains(m.id)) m.id,
          ]
        : [
            for (final c in query.cards)
              if (visibleModules.contains(c)) c,
          ];
    final report =
        open?.definition?.report ??
        BiReportDefinition.standard(
          query: query,
          cards: cards,
          pageTitle: l10n.biReportPageTitle,
        );
    try {
      final copy = await ref
          .read(biViewActionsProvider)
          .save(
            workspaceId,
            scope: BiViewScope.private,
            name: l10n.biReportCopyName(open?.name ?? l10n.biViewStandard),
            definition: BiViewDefinition.ofReport(report),
          );
      onOpen(copy, report.query ?? query);
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report copy refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(biViewFailureText(l10n, e.failure))),
      );
    }
  }
}
