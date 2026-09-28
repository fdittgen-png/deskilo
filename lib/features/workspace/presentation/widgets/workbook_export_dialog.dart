// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1661 — a template workbook export says where it stands (reading,
// building, saving) and can be cancelled until the save dialog opens.
// A cancel saves nothing and leaves nothing behind; a failure is rethrown
// to the caller, never reported as a cancel.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/template_workbook.dart';

/// Runs one export behind a progress dialog. Returns the saved location
/// (null when the save dialog was dismissed) and whether it was
/// cancelled before the save; rethrows anything else.
Future<({String? path, bool cancelled})> exportWorkbookWithProgress(
  BuildContext context,
  TemplateWorkbookExport exporter,
  List<String> templateIds, {
  required DateTime now,
  WorkbookLabels? labels,
}) async {
  final outcome = await showDialog<_Outcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WorkbookExportDialog(
      run: (onProgress, cancel) => exporter.export(
        templateIds,
        now: now,
        labels: labels,
        onProgress: onProgress,
        cancel: cancel,
      ),
    ),
  );
  if (outcome == null) return (path: null, cancelled: true);
  if (outcome.error case final error?) {
    Error.throwWithStackTrace(error, outcome.stack ?? StackTrace.current);
  }
  return (path: outcome.path, cancelled: outcome.cancelled);
}

/// Says what happened: saved, or cancelled with nothing saved. A save
/// dialog the person dismissed says nothing, as before.
void showWorkbookExportResult(
  BuildContext context,
  ({String? path, bool cancelled})? result,
) {
  final l10n = AppLocalizations.of(context);
  if (result == null) return;
  if (result.cancelled) {
    AppSnack.info(
      context,
      l10n?.workbookExportCancelled ?? 'Export cancelled. Nothing was saved.',
    );
  } else if (result.path != null) {
    AppSnack.success(context, l10n?.compareExported ?? 'Workbook saved.');
  }
}

class _Outcome {
  const _Outcome({this.path, this.cancelled = false, this.error, this.stack});
  final String? path;
  final bool cancelled;
  final Object? error;
  final StackTrace? stack;
}

class _WorkbookExportDialog extends StatefulWidget {
  const _WorkbookExportDialog({required this.run});

  final Future<String?> Function(
    void Function(WorkbookProgress) onProgress,
    WorkbookCancel cancel,
  )
  run;

  @override
  State<_WorkbookExportDialog> createState() => _WorkbookExportDialogState();
}

class _WorkbookExportDialogState extends State<_WorkbookExportDialog> {
  final _cancel = WorkbookCancel();
  WorkbookProgress? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    _Outcome outcome;
    try {
      final path = await widget.run((p) {
        if (mounted) setState(() => _progress = p);
      }, _cancel);
      outcome = _Outcome(path: path);
    } on WorkbookCancelled {
      outcome = const _Outcome(cancelled: true);
    } catch (e, st) {
      // trace-exempt: handed to the caller, which reports it with context.
      outcome = _Outcome(error: e, stack: st);
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _progress;
    final saving = p?.stage == WorkbookStage.saving;
    final label = switch (p?.stage) {
      WorkbookStage.building =>
        l10n?.workbookExportBuilding ?? 'Building the workbook…',
      WorkbookStage.saving =>
        l10n?.workbookExportSaving ?? 'Choose where to save it…',
      _ =>
        l10n?.workbookExportReading('${p?.done ?? 0}', '${p?.total ?? 0}') ??
            'Reading templates: ${p?.done ?? 0} of ${p?.total ?? 0}',
    };
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('workbook-export-dialog'),
        title: Text(l10n?.workbookExportTitle ?? 'Exporting the workbook'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(label, key: const ValueKey('workbook-export-stage')),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value:
                  p == null || p.total == 0 || p.stage != WorkbookStage.reading
                  ? null
                  : p.done / p.total,
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('workbook-export-cancel'),
            onPressed: saving || _cancel.isCancelled
                ? null
                : () => setState(_cancel.cancel),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }
}
