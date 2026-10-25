// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the report editor says about the draft, above the page:
//   * someone saved the report since this draft was read: reload theirs
//     (this draft is dropped) or keep this draft as a private copy — never
//     an overwrite;
//   * the answer to a save was lost: Retry resends the same request, which
//     the server applies once;
//   * the server refused the save, and why;
//   * why the last change did nothing (a limit, a figure that cannot be
//     shown that way): the visual keeps its previous valid binding.
// Each notice is a live region, so a screen reader hears it when it appears.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../application/report_editor/bi_report_editor.dart';
import '../../application/report_editor/bi_report_editor_state.dart';
import '../widgets/bi_report_parts.dart' show BiReportNotice;
import '../widgets/bi_view_failure_text.dart';
import 'bi_report_labels.dart';

class BiEditorNotices extends ConsumerWidget {
  const BiEditorNotices({
    super.key,
    required this.provider,
    required this.onCopy,
  });

  final BiReportEditorProvider provider;

  /// Keeps the draft as a new private report.
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(provider);
    final editor = ref.read(provider.notifier);
    final reason = s.refusal != null
        ? biEditRefusalText(l10n, s.refusal!)
        : s.binding != null
        ? biBindingRefusalText(l10n, s.binding!)
        : null;
    Widget live(Widget child) => Semantics(liveRegion: true, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.save == BiEditorSave.conflict)
          live(
            BiReportNotice(
              key: const ValueKey('bi-editor-conflict'),
              text: l10n.biEditorConflict,
              actions: [
                TextButton(
                  key: const ValueKey('bi-editor-reload'),
                  onPressed: () => unawaited(editor.reload()),
                  child: Text(l10n.biEditorReload),
                ),
                TextButton(
                  key: const ValueKey('bi-editor-keep-copy'),
                  onPressed: () => unawaited(onCopy()),
                  child: Text(l10n.biEditorKeepAsCopy),
                ),
              ],
            ),
          ),
        if (s.save == BiEditorSave.lost)
          live(
            BiReportNotice(
              key: const ValueKey('bi-editor-lost'),
              text: l10n.biReportSaveFailed,
              actions: [
                TextButton(
                  key: const ValueKey('bi-editor-retry'),
                  onPressed: () => unawaited(editor.retry()),
                  child: Text(l10n.biReportRetry),
                ),
              ],
            ),
          ),
        if (s.save == BiEditorSave.refused && s.failure != null)
          live(
            Text(
              biViewFailureText(l10n, s.failure!),
              key: const ValueKey('bi-editor-refused'),
            ),
          ),
        if (reason != null)
          live(Text(reason, key: const ValueKey('bi-editor-refusal'))),
      ],
    );
  }
}
