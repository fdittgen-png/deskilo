// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- Stock counts (`/stock/counts`): what was counted against what
// the ledger held, with the state each count is in. A count that waits for
// approval says so, visibly; one the stock has moved since says it must be
// counted again and offers no apply. Whoever manages the stock counts; whoever
// may approve adjustments applies or rejects; the author or an approver
// cancels. Nothing moves by recording: only an applied count posts its
// difference. A refusal says why and changes nothing. A failed read says so
// and can be asked again, never shown as empty.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_count_decisions.dart';
import '../domain/stock_page.dart';
import '../domain/stock_reversals.dart';
import '../domain/stock_sites.dart';
import '../providers/stock_providers.dart';
import 'stock_config_text.dart';
import 'stock_move_sheets.dart' show StockPickField;
import 'stock_page_shell.dart';
import 'stock_quantity_field.dart';
import 'stock_sheet_opener.dart';

class StockCountsScreen extends ConsumerWidget {
  const StockCountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final held = ref.watch(myPermissionsProvider);
    final mayCount = held.contains(WorkspacePermission.manageStock);
    return StockPageShell(
      title: l10n.stockCountsTitle,
      anchor: HelpAnchor.moneyStockReversals,
      helpTopic: l10n.permModuleStock,
      reloadKey: const ValueKey('stock-counts-reload'),
      reloads: (workspaceId) => [stockCountsProvider(workspaceId)],
      body: (context, ref, workspaceId) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (mayCount)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('stock-count-open'),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l10n.stockCountsOpen),
                onPressed: () => _count(context, ref, workspaceId),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _Counts(
            workspaceId: workspaceId,
            decisions: StockCountDecisions(
              mayApprove: held.contains(WorkspacePermission.approveStockAdjustments),
              mayManage: mayCount,
              memberId: ref.watch(myMemberProvider).value?.id,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _count(BuildContext context, WidgetRef ref, String workspaceId) => openStockSheet(
    context,
    ref,
    workspaceId,
    what: 'count',
    open: (choices) => _showCountSheet(
      context,
      ref.read(stockReversalsProvider),
      workspaceId: workspaceId,
      items: choices.items,
      places: choices.places,
    ),
    reads: [stockCountsProvider(workspaceId)],
  );
}

class _Counts extends ConsumerWidget {
  const _Counts({required this.workspaceId, required this.decisions});

  final String workspaceId;
  final StockCountDecisions decisions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counts = ref.watch(stockCountsProvider(workspaceId));
    final items = {for (final i in ref.watch(stockItemsProvider(workspaceId)).value ?? const <StockItem>[]) i.id: i}; // empty-ok: a count is named by its ids
    final places = {for (final p in ref.watch(stockPlaceConfigsProvider(workspaceId)).value ?? const <StockPlaceConfig>[]) p.id: p}; // empty-ok: a count is named by its ids
    return StockRead<List<StockCountRow>>(
      keyName: 'stock-counts',
      value: counts,
      onRetry: () => ref.invalidate(stockCountsProvider(workspaceId)),
      isEmpty: (list) => list.isEmpty,
      empty: l10n.stockCountsEmpty,
      emptyIcon: Icons.fact_check_outlined,
      data: (list) => Column(
        children: [
          for (final c in list)
            _CountTile(
              count: c,
              item: items[c.itemId],
              place: places[c.locationId],
              decisions: decisions.on(c),
              workspaceId: workspaceId,
            ),
        ],
      ),
    );
  }
}

class _CountTile extends ConsumerWidget {
  const _CountTile({
    required this.count,
    required this.item,
    required this.place,
    required this.decisions,
    required this.workspaceId,
  });

  final StockCountRow count;
  final StockItem? item;
  final StockPlaceConfig? place;

  /// What the reader may decide on this count (StockCountDecisions).
  final List<StockCountDecision> decisions;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unit = item?.unit ?? '';
    final difference = count.difference;
    final fmt = appFormatOf(context);
    // the quantities in the member's format (1,5 in French), the difference with its sign
    final sign = difference > ExactQuantity.zero ? '+${fmt.quantity(difference)}' : fmt.quantity(difference);
    final open = count.state == StockCountState.recorded;
    return Card(
      key: ValueKey('stock-count-${count.countId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stockCountsLine(
                item?.name ?? count.itemId,
                place == null ? count.locationId : place!.code,
                fmt.quantity(count.observed, unit: unit),
                fmt.quantity(count.baseline, unit: unit),
                '$sign $unit',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            StatusChip(
              key: ValueKey('stock-count-state-${count.countId}'),
              label: switch (count.state) {
                StockCountState.recorded => l10n.stockCountsStateRecorded,
                StockCountState.applied => l10n.stockCountsStateApplied,
                StockCountState.rejected => l10n.stockCountsStateRejected,
                StockCountState.cancelled => l10n.stockCountsStateCancelled,
                StockCountState.unknown => l10n.stockStateUnknown,
              },
              // waiting for a decision, posted, refused, or nothing to act on
              tone: switch (count.state) {
                StockCountState.recorded => StatusTone.warn,
                StockCountState.applied => StatusTone.ok,
                StockCountState.rejected => StatusTone.due,
                StockCountState.cancelled || StockCountState.unknown => StatusTone.neutral,
              },
            ),
            if (open && count.stale)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.stockCountsStale,
                  key: ValueKey('stock-count-stale-${count.countId}'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (open)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (decisions.contains(StockCountDecision.apply))
                    FilledButton(
                      key: ValueKey('stock-count-apply-${count.countId}'),
                      onPressed: () => _decide(context, ref, StockCountDecision.apply),
                      child: Text(l10n.stockCountsApply),
                    ),
                  if (decisions.contains(StockCountDecision.reject))
                    OutlinedButton(
                      key: ValueKey('stock-count-reject-${count.countId}'),
                      onPressed: () => _decide(context, ref, StockCountDecision.reject),
                      child: Text(l10n.stockCountsReject),
                    ),
                  if (decisions.contains(StockCountDecision.cancel))
                    TextButton(
                      key: ValueKey('stock-count-cancel-${count.countId}'),
                      onPressed: () => _decide(context, ref, StockCountDecision.cancel),
                      child: Text(l10n.stockCountsCancel),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, StockCountDecision decision) async {
    final l10n = context.l10n;
    final problem = await guardSave(
      domain: 'stock',
      message: 'a count was not decided',
      action: () async {
        await ref.read(stockReversalsProvider).decideCount(workspaceId, count.countId, decision, newRequestId());
        ref
          ..invalidate(stockOnHandWalkProvider)
          ..invalidate(stockMovementsWalkProvider);
      },
      problem: (e) => stockProblemText(l10n, e),
    );
    // decided or refused, the count is read again: a stale or decided count shows what the server holds
    ref.invalidate(stockCountsProvider(workspaceId));
    if (problem != null && context.mounted) AppSnack.error(context, problem);
  }
}

Future<bool> _showCountSheet(
  BuildContext context,
  StockReversals reversals, {
  required String workspaceId,
  required List<StockItem> items,
  required List<StockPlaceConfig> places,
}) {
  final l10n = context.l10n;
  final draft = _CountDraft(items, stockRealPlaces(places), appFormatOf(context).locale);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockCountsOpen,
      submitLabel: l10n.stockCountsSubmit,
      submitKey: const ValueKey('stock-count-submit'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n, reversals, workspaceId),
      builder: draft.build,
    ),
  );
}

class _CountDraft {
  _CountDraft(this.items, this.places, this.locale) : fields = FormControllers({'observed': '', 'reason': ''});

  final List<StockItem> items;
  final List<StockPlaceConfig> places;
  final String locale;
  final FormControllers fields;

  /// One identity per form: the count and the request, so a retry answers once.
  final String countId = newRequestId();
  final String requestId = newRequestId();
  String? item;
  String? place;

  StockItem? get chosen => items.where((i) => i.id == item).firstOrNull;

  ExactQuantity? get observed => stockQuantityOrNull(fields.text('observed'), locale: locale);

  FieldErrors validate(AppLocalizations l10n) => {
    if (item == null) 'item': l10n.stockRequiredItem,
    if (place == null) 'place': l10n.stockRequiredPlace,
    if (observed == null || observed! < ExactQuantity.zero) 'observed': stockRefusalText(l10n, StockRefusal.quantityInvalid),
  };

  Future<String?> submit(AppLocalizations l10n, StockReversals reversals, String workspaceId) async {
    return guardSave(
      domain: 'stock',
      message: 'a count was not recorded',
      action: () async {
        await reversals.recordCount(workspaceId, (
          countId: countId,
          itemId: item!,
          locationId: place!,
          observed: observed!.text,
          requestId: requestId,
          variantId: null,
          lotId: null,
          reason: fields.text('reason').trim(),
        ));
      },
      problem: (e) => stockProblemText(l10n, e),
    );
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      StockPickField(
        keyName: 'item',
        label: l10n.stockCountsItem,
        value: item,
        options: [for (final i in items) (i.id, i.name)],
        onPicked: (v) {
          item = v;
          refresh();
        },
      ),
      const FormGap(),
      StockPickField(
        keyName: 'place',
        label: l10n.stockCountsPlace,
        value: place,
        options: [for (final p in places) (p.id, p.name.isEmpty ? p.code : '${p.code} · ${p.name}')],
        onPicked: (v) {
          place = v;
          refresh();
        },
      ),
      const FormGap(),
      StockQuantityField(
        key: const ValueKey('stock-count-observed'),
        controller: fields['observed'],
        fieldKey: 'observed',
        label: l10n.stockCountsObserved(chosen?.unit ?? ''),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-count-reason'),
        controller: fields['reason'],
        fieldKey: 'reason',
        label: l10n.stockCountsReason,
      ),
    ];
  }
}
