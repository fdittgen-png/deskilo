// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2580 — Reporting → Business analytics → Edit report: the saved report
// `/bi/report/<id>` opened in its editor. The report is read once, at the
// revision the draft starts from; a save never reopens it under the person
// (the editor keeps its own state and history), so someone else's save meets
// the draft as a conflict, never as a silent replacement.
//
// Opened only while `biReportDesigner` is on (the route says so). A report
// this reader may not change — a team report without the right to share, a
// report holding figures withheld from them, a question that is not a report
// — is not edited here: the page says so and leads back to the analytics.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/report_editor/bi_report_editor_state.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_views_bar.dart' show biCanShareViews;
import 'bi_report_editor_view.dart';

class BiReportEditorScreen extends ConsumerStatefulWidget {
  const BiReportEditorScreen({super.key, required this.viewId});

  /// The saved report's id, from the address.
  final String viewId;

  @override
  ConsumerState<BiReportEditorScreen> createState() =>
      _BiReportEditorScreenState();
}

class _BiReportEditorScreenState extends ConsumerState<BiReportEditorScreen> {
  /// The report as first read: the editor's seed for its whole life.
  BiReportEditorSeed? _seed;

  @override
  void didUpdateWidget(BiReportEditorScreen old) {
    super.didUpdateWidget(old);
    // The address now names another report (a copy just saved): read it.
    if (old.viewId != widget.viewId) _seed = null;
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed;
    if (seed != null) return BiReportEditorView(seed: seed);
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    if (workspaceId == null) return const _Frame(child: LoadingView());
    final views = ref.watch(biViewsProvider(workspaceId));
    if (views.isLoading && !views.hasValue) {
      return const _Frame(child: LoadingView());
    }
    final view = views.value?.where((v) => v.id == widget.viewId).firstOrNull;
    final canShare = biCanShareViews(ref.watch(myPermissionsProvider));
    if (view == null || !biReportEditable(view, canShare: canShare)) {
      return const _Frame(child: _NotEditable());
    }
    final next = BiReportEditorSeed(workspaceId, view);
    _seed = next;
    return BiReportEditorView(seed: next);
  }
}

/// Whether this reader may change [view] in the editor: a report, every
/// figure of it readable by them, theirs (private) or the team's when they
/// may share views.
bool biReportEditable(BiSavedView view, {required bool canShare}) =>
    view.definition?.report != null &&
    view.withheld == 0 &&
    (view.scope == BiViewScope.private ? view.mine : canShare);

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.biEditorTitle)),
    body: child,
  );
}

class _NotEditable extends StatelessWidget {
  const _NotEditable();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.biEditorNotEditable,
            key: const ValueKey('bi-editor-not-editable'),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('bi-editor-to-analytics'),
            onPressed: () => context.go('/bi'),
            child: Text(l10n.biTitle),
          ),
        ],
      ),
    );
  }
}
