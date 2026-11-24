// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- Transfers: the goods that are on their way between two sites,
// what each load still holds, and the actions that move goods: moving them
// (at once inside a site, loaded onto the way between sites), receiving what
// arrived (all or in part, onto a place of the destination site) and taking
// goods out for use or as a loss. What is not received stays on the way and
// stays visible. The server decides who may; this screen asks the same.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_operations.dart';
import '../domain/stock_sites.dart';
import '../providers/stock_providers.dart';
import 'stock_config_text.dart';
import 'stock_day.dart';
import 'stock_move_sheets.dart';
import 'stock_page_shell.dart';
import 'stock_place_text.dart';
import 'stock_quantity_field.dart';
import 'stock_sheet_opener.dart';

class StockTransfersScreen extends ConsumerWidget {
  const StockTransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final takeOutOn = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockTakeOut);
    return StockPageShell(
      title: l10n.stockTransfersTitle,
      reloadKey: const ValueKey('stock-transfers-reload'),
      reloads: (workspaceId) => [openTransfersProvider(workspaceId)],
      body: (context, ref, workspaceId) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (mayManage)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  key: const ValueKey('stock-move-open'),
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l10n.stockMoveOpen),
                  onPressed: () => _move(context, ref, workspaceId, takeOut: false),
                ),
                if (takeOutOn)
                  OutlinedButton.icon(
                    key: const ValueKey('stock-takeout-open'),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(l10n.stockTakeOutOpen),
                    onPressed: () => _move(context, ref, workspaceId, takeOut: true),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.stockTransfersOnTheWay, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OnTheWay(workspaceId: workspaceId, mayManage: mayManage),
        ],
      ),
    );
  }

  Future<void> _move(BuildContext context, WidgetRef ref, String workspaceId, {required bool takeOut}) => StockSheetOpener(ref).open(
    context,
    workspaceId,
    what: 'move',
    sheet: (choices) => showStockMoveSheet(
      context,
      ref.read(stockOperationsProvider),
      workspaceId: workspaceId,
      items: choices.items,
      places: choices.places,
      takeOut: takeOut,
    ),
    reads: [openTransfersProvider(workspaceId)],
  );
}

class _OnTheWay extends ConsumerWidget {
  const _OnTheWay({required this.workspaceId, required this.mayManage});

  final String workspaceId;
  final bool mayManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final transfers = ref.watch(openTransfersProvider(workspaceId));
    return StockRead<List<StockTransfer>>(
      keyName: 'stock-transfers',
      value: transfers,
      onRetry: () => ref.invalidate(openTransfersProvider(workspaceId)),
      isEmpty: (list) => list.isEmpty,
      empty: l10n.stockTransfersEmpty,
      emptyIcon: Icons.local_shipping_outlined,
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final t in list) _TransferCard(transfer: t, workspaceId: workspaceId, mayManage: mayManage)],
      ),
    );
  }
}

class _TransferCard extends ConsumerWidget {
  const _TransferCard({required this.transfer, required this.workspaceId, required this.mayManage});

  final StockTransfer transfer;
  final String workspaceId;
  final bool mayManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final day = appFormatOf(context).dates(DateShape.numeric).format(stockDayOf(ref, transfer.loadedAt));
    final addresses = ref.watch(stockAddressesProvider(workspaceId));
    return Card(
      key: ValueKey('stock-transfer-${transfer.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.stockTransferRoute(
                      addresses[transfer.fromLocationId] ?? transfer.fromCode,
                      addresses[transfer.toLocationId] ?? transfer.toCode,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                StatusChip(
                  key: ValueKey('stock-transfer-status-${transfer.id}'),
                  // part of the load arrived: something to finish; the rest is on its way
                  label: transfer.status == 'partly_received' ? l10n.stockTransferStatusPartly : l10n.stockTransfersOnTheWay,
                  tone: transfer.status == 'partly_received' ? StatusTone.warn : StatusTone.info,
                ),
              ],
            ),
            Text(l10n.stockTransferLoadedOn(day), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final line in transfer.lines)
              if (!line.inTransit.isZero)
                Text(
                  key: ValueKey('stock-transfer-line-${line.id}'),
                  l10n.stockTransferLine(line.itemName, line.inTransit.text, line.unit, line.loaded.text),
                ),
            if (mayManage)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: ValueKey('stock-transfer-receive-${transfer.id}'),
                  onPressed: () => _receive(context, ref),
                  child: Text(l10n.stockTransferReceive),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _receive(BuildContext context, WidgetRef ref) => StockSheetOpener(ref).open(
    context,
    workspaceId,
    what: 'receive',
    sheet: (choices) => _showReceiveSheet(
      context,
      ref.read(stockOperationsProvider),
      workspaceId: workspaceId,
      transfer: transfer,
      places: choices.places,
      separator: choices.separator,
    ),
    reads: [openTransfersProvider(workspaceId)],
  );
}

/// Receives what arrived of [transfer], all or in part; true when done.
Future<bool> _showReceiveSheet(
  BuildContext context,
  StockOperations operations, {
  required String workspaceId,
  required StockTransfer transfer,
  required List<StockPlaceConfig> places,
  required String separator,
}) {
  final l10n = context.l10n;
  final draft = _ReceiveDraft(transfer, places, appFormatOf(context).locale, separator);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockTransferReceiveTitle,
      submitLabel: l10n.stockTransferReceive,
      submitKey: const ValueKey('stock-receive-submit'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n, operations, workspaceId),
      builder: draft.build,
    ),
  );
}

class _ReceiveDraft {
  _ReceiveDraft(this.transfer, List<StockPlaceConfig> places, this.locale, this.separator)
    : lines = [for (final l in transfer.lines) if (!l.inTransit.isZero) l],
      targets = [
        for (final p in stockRealPlaces(places))
          if (stockSiteOf(p.id, places) == stockSiteOf(transfer.toLocationId, places)) p,
      ],
      to = transfer.toLocationId,
      fields = FormControllers({
        for (final l in transfer.lines)
          if (!l.inTransit.isZero) l.id: l.inTransit.text,
      });

  final StockTransfer transfer;
  final String locale;
  final String separator;
  final List<StockTransferLine> lines;
  final List<StockPlaceConfig> targets;
  final FormControllers fields;

  /// One per form: a retry of the same receive answers once.
  final String requestId = newRequestId();
  String to;

  ExactQuantity? _typed(StockTransferLine l) => stockQuantityOrNull(fields.text(l.id), locale: locale);

  FieldErrors validate(AppLocalizations l10n) {
    final errors = <String, String>{};
    var any = false;
    for (final l in lines) {
      final q = _typed(l);
      if (q == null || q < ExactQuantity.zero) {
        errors[l.id] = stockRefusalText(l10n, StockRefusal.quantityInvalid);
      } else if (q > l.inTransit) {
        errors[l.id] = stockRefusalText(l10n, StockRefusal.receiveOver);
      } else if (q > ExactQuantity.zero) {
        any = true;
      }
    }
    if (!any && errors.isEmpty && lines.isNotEmpty) errors[lines.first.id] = stockRefusalText(l10n, StockRefusal.quantityInvalid);
    return errors;
  }

  Future<String?> submit(AppLocalizations l10n, StockOperations operations, String workspaceId) async {
    return guardSave(
      domain: 'stock',
      message: 'goods were not received',
      action: () async {
        await operations.receive(workspaceId, transfer.id, [
          for (final l in lines)
            if ((_typed(l) ?? ExactQuantity.zero) > ExactQuantity.zero)
              (lineId: l.id, quantity: _typed(l)!.text, toLocationId: to),
        ], requestId);
      },
      problem: (e) => stockProblemText(l10n, e),
    );
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      Text(l10n.stockTransferReceiveHint, style: Theme.of(context).textTheme.bodySmall),
      const FormGap(),
      DropdownButtonFormField<String>(
        key: const ValueKey('stock-receive-to'),
        initialValue: to,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockTransferReceiveTo),
        items: [
          for (final p in targets)
            DropdownMenuItem(value: p.id, child: Text(stockPlaceTitle(p, separator))),
        ],
        onChanged: (v) {
          to = v ?? to;
          refresh();
        },
      ),
      for (final l in lines) ...[
        const FormGap(),
        StockQuantityField(
          key: ValueKey('stock-receive-${l.id}'),
          controller: fields[l.id],
          fieldKey: l.id,
          label: l10n.stockTransferReceiveQuantity(l.itemName, l.unit),
        ),
      ],
    ];
  }
}
