// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- one cycle count task (`/stock/cycle-counts/:taskId`), counted BLIND: each line says what to
// count and where and never what the ledger expects, so the count is not biased; a scan (or a typed
// barcode) finds the line. Counting records a count of #4172 (its approval and its adjustment are that
// leaf's); a person who may only count is told the line is counted and nothing more, while one who may
// approve is told the difference. A line is skipped with a reason. The task is complete when every line
// is counted or skipped; one that is no longer open says so. Each sheet carries ONE request id: a retry
// answers once. A failed read says so and can be asked again.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/adaptive/task_surface.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_cycle_counts.dart';
import '../domain/stock_page.dart';
import '../providers/stock_providers.dart';
import 'stock_bulk_read_sheet.dart';
import 'stock_config_text.dart';
import 'stock_read_failed.dart';

class StockCountTaskScreen extends ConsumerStatefulWidget {
  const StockCountTaskScreen({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<StockCountTaskScreen> createState() => _State();
}

class _State extends ConsumerState<StockCountTaskScreen> {
  final _scan = TextEditingController();
  String? _scanProblem;

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  /// Opens the line still to count whose item has the scanned barcode.
  Future<void> _find(String workspaceId, CountTask task, Map<String, StockItem> items, Map<String, String> places) async {
    final code = _scan.text.trim();
    if (code.isEmpty) return;
    final l10n = context.l10n;
    try {
      // The same resolver every other scan uses: the registry's size does not matter. A code that names a variant or a
      // lot opens only the line of that variant or lot; one that names neither and fits several pending lines (an item
      // kept in two places) asks which, instead of taking the first.
      final answer = await ref.read(stockCodeResolverProvider).resolve(workspaceId, code);
      final itemId = answer.item?.id;
      final fits = itemId == null || itemId.isEmpty
          ? const <CountTaskLine>[]
          : [
              for (final l in task.lines)
                if (l.state == CountLineState.pending &&
                    l.itemId == itemId &&
                    (answer.variantId == null || l.variantId == answer.variantId) &&
                    (answer.lotId == null || l.lotId == answer.lotId))
                  l,
            ];
      if (!mounted) return;
      final line = fits.length > 1 ? await _choose(fits, places) : fits.firstOrNull;
      if (!mounted) return;
      setState(() => _scanProblem = line == null ? l10n.stockCycleScanNone : null);
      if (line == null) return;
      _scan.clear();
      await _countSheet(workspaceId, line, items[line.itemId]?.unit ?? '');
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the barcodes could not be read', error: e, stackTrace: st);
      if (mounted) AppSnack.error(context, l10n.stockReadFailed);
    }
  }

  /// Which of several pending lines the scanned code is for: one button per line, by its place.
  Future<CountTaskLine?> _choose(List<CountTaskLine> lines, Map<String, String> places) => showDialog<CountTaskLine>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text(c.l10n.stockCycleScanWhich),
      children: [
        for (final l in lines)
          SimpleDialogOption(
            key: ValueKey('stock-cycle-scan-pick-${l.lineId}'),
            onPressed: () => Navigator.of(c).pop(l),
            child: Text(places[l.locationId] ?? l.locationId),
          ),
      ],
    ),
  );

  /// #4364 -- "Read many tags": the tags a UHF reader typed fill the counted lines of this task (blind: the counter is
  /// told what it read, never what was expected). The read waits for its approval like any count; no balance moves.
  Future<void> _bulkRead(String workspaceId) async {
    final l10n = context.l10n;
    final requestId = newRequestId();
    BulkCountResult? answer;
    final done = await showTask<bool>(
      context,
      size: TaskSize.standard,
      builder: (c) => StockBulkReadSheet(
        workspaceId: workspaceId,
        confirmLabel: l10n.stockBulkReadConfirm,
        onConfirm: (resolution, codes) async {
          try {
            answer = await ref.read(stockCycleCountsProvider).countByTagRead(workspaceId, requestId: requestId, taskId: widget.taskId, codes: codes);
            return null;
          } on Object catch (e, st) {
            TraceLogger.instance.warn('stock', 'a bulk read was not counted', error: e, stackTrace: st);
            return knownRefusalText(l10n, e) ?? stockSaveProblem(l10n, e);
          }
        },
      ),
    );
    if (done != true || !mounted) return;
    _refresh(workspaceId);
    final r = answer;
    if (r != null) AppSnack.success(context, l10n.stockBulkReadDone(r.lines.length, r.leftOut.length));
  }

  void _refresh(String workspaceId) {
    ref
      ..invalidate(stockCountTaskProvider((workspaceId: workspaceId, taskId: widget.taskId)))
      ..invalidate(stockCountTasksProvider(workspaceId));
  }

  Future<void> _countSheet(String workspaceId, CountTaskLine line, String unit) async {
    final l10n = context.l10n;
    final fields = FormControllers({'observed': ''});
    final requestId = newRequestId();
    final locale = appFormatOf(context).locale;
    // what was counted, read in the member's format (1,5 or 1.5) and sent as the exact text the server reads
    String? observed() => exactQuantityFromInput(fields.text('observed'), locale: locale).value?.text;
    CountLineResult? result;
    final done = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.stockCycleCountTitle,
        submitLabel: l10n.stockEditSave,
        submitKey: const ValueKey('stock-cycle-count-save'),
        onDispose: fields.dispose,
        validate: () => observed() != null ? const {} : {'observed': stockReasonText(l10n, 'quantity_invalid')},
        onSubmit: () async {
          try {
            result = await ref
                .read(stockCycleCountsProvider)
                .countLine(workspaceId, line.lineId, observed()!, requestId);
            return null;
          } on Object catch (e, st) {
            TraceLogger.instance.warn('stock', 'a line was not counted', error: e, stackTrace: st);
            return knownRefusalText(l10n, e) ?? stockSaveProblem(l10n, e);
          }
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('stock-cycle-observed'),
            controller: fields['observed'],
            fieldKey: 'observed',
            label: l10n.stockCycleCountObserved(unit),
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          ),
        ],
      ),
    );
    if (!done || !mounted) return;
    _refresh(workspaceId);
    final difference = result?.difference;
    AppSnack.success(context, difference == null ? l10n.stockCycleCounted : l10n.stockCycleCountedDifference(difference.text));
  }

  Future<void> _skipSheet(String workspaceId, CountTaskLine line) async {
    final l10n = context.l10n;
    final fields = FormControllers({'reason': ''});
    final requestId = newRequestId();
    final done = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.stockCycleSkipTitle,
        submitLabel: l10n.stockEditSave,
        submitKey: const ValueKey('stock-cycle-skip-save'),
        onDispose: fields.dispose,
        validate: () => fields.text('reason').trim().isEmpty ? {'reason': l10n.stockCycleSkipReason} : const {},
        onSubmit: () async {
          try {
            await ref.read(stockCycleCountsProvider).skipLine(workspaceId, line.lineId, fields.text('reason').trim(), requestId);
            return null;
          } on Object catch (e, st) {
            TraceLogger.instance.warn('stock', 'a line was not skipped', error: e, stackTrace: st);
            return knownRefusalText(l10n, e) ?? stockSaveProblem(l10n, e);
          }
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('stock-cycle-skip-reason'),
            controller: fields['reason'],
            fieldKey: 'reason',
            label: l10n.stockCycleSkipReason,
            autofocus: true,
          ),
        ],
      ),
    );
    if (!done || !mounted) return;
    _refresh(workspaceId);
    AppSnack.success(context, l10n.stockCycleSkipped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockCycleTaskTitle),
        actions: [HelpDot(l10n.permModuleStock, anchor: HelpAnchor.moneyStockCycleCounts)],
      ),
      body: workspaceId == null ? const LoadingView() : _body(context, workspaceId),
    );
  }

  Widget _body(BuildContext context, String workspaceId) {
    final l10n = context.l10n;
    final provider = stockCountTaskProvider((workspaceId: workspaceId, taskId: widget.taskId));
    final items = {for (final i in ref.watch(stockItemsProvider(workspaceId)).value ?? const <StockItem>[]) i.id: i}; // empty-ok: a name falls back to its id
    final separator = ref.watch(stockAddressSeparatorProvider);
    final places = {
      for (final p in ref.watch(stockPlaceConfigsProvider(workspaceId)).value ?? const <StockPlaceConfig>[]) p.id: stockAddress(p, separator), // empty-ok: a place falls back to its id
    };
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => StockReadFailed(keyName: 'stock-cycle-task', error: e, onRetry: () => ref.invalidate(provider)),
          data: (task) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(l10n.stockCycleBlind, key: const ValueKey('stock-cycle-blind'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (task.state == CountTaskState.open) ...[
                AppTextField(
                  key: const ValueKey('stock-cycle-scan'),
                  controller: _scan,
                  label: l10n.stockCycleScan,
                  error: _scanProblem,
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _find(workspaceId, task, items, places),
                ),
                if (ref.watch(stockTagReadsProvider))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: const ValueKey('stock-bulk-open'),
                      onPressed: () => _bulkRead(workspaceId),
                      icon: const Icon(Icons.sensors),
                      label: Text(l10n.stockBulkReadOpen),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (task.lines.isEmpty) Text(l10n.stockCycleTaskNoLines, key: const ValueKey('stock-cycle-no-lines')),
              if (task.state == CountTaskState.complete) Text(l10n.stockCycleTaskDone, key: const ValueKey('stock-cycle-done')),
              for (final line in task.lines)
                _LineTile(
                  line: line,
                  item: items[line.itemId],
                  place: places[line.locationId] ?? line.locationId,
                  open: task.state == CountTaskState.open,
                  onCount: () => _countSheet(workspaceId, line, items[line.itemId]?.unit ?? ''),
                  onSkip: () => _skipSheet(workspaceId, line),
                ),
            ],
          ),
        );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.item, required this.place, required this.open, required this.onCount, required this.onSkip});

  final CountTaskLine line;
  final StockItem? item;
  final String place;
  final bool open;
  final VoidCallback onCount;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = line.state == CountLineState.pending && open;
    return ListTile(
      key: ValueKey('stock-cycle-line-${line.lineId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(item?.name ?? line.itemId),
      subtitle: Text(
        [
          place,
          switch (line.state) {
            CountLineState.counted => l10n.stockCycleLineCounted,
            CountLineState.skipped => l10n.stockCycleLineSkipped(line.skipReason ?? ''),
            CountLineState.pending => '',
            CountLineState.unknown => l10n.stockStateUnknown,
          },
        ].where((t) => t.isNotEmpty).join(' · '),
      ),
      trailing: pending
          ? Wrap(
              spacing: AppSpacing.xs,
              children: [
                OutlinedButton(key: ValueKey('stock-cycle-count-${line.lineId}'), onPressed: onCount, child: Text(l10n.stockCycleLineCount)),
                TextButton(key: ValueKey('stock-cycle-skip-${line.lineId}'), onPressed: onSkip, child: Text(l10n.stockCycleLineSkip)),
              ],
            )
          : null,
    );
  }
}
