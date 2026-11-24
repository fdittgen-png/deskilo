// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- "Add an item" on the Stock page. An item IS a service whose stock setting is on, so an item is
// added in one of two ways: a NEW item (one sheet with its name, price, VAT, unit, barcode and home place,
// offered to whoever may manage both the services and the stock), or an EXISTING service of the business
// that is not kept in stock yet, whose stock settings open with the setting already on. A business with
// neither is told to add a service and is taken to its services. Nothing is written by choosing: only the
// saves write, once per sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_page.dart';
import '../providers/stock_providers.dart';
import 'stock_item_editor.dart';
import 'stock_item_new_sheet.dart';

/// What the add dialog answers: a new item, or the service chosen.
typedef _Choice = ({bool brandNew, StockItem? service});

/// The add flow of one Stock page.
class StockItemAdd {
  const StockItemAdd(this._ref);

  final WidgetRef _ref;

  /// Chooses how to add an item and does it; true when an item was made.
  Future<bool> run(BuildContext context, String workspaceId) async {
    final l10n = context.l10n;
    final List<StockItem> candidates;
    try {
      candidates = await _ref.read(stockQueriesProvider).unstocked(workspaceId);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the services that may become items could not be read: $e', stackTrace: st);
      if (context.mounted) AppSnack.error(context, l10n.stockReadFailed);
      return false;
    }
    if (!context.mounted) return false;
    final held = _ref.read(myPermissionsProvider);
    final mayCreate = _ref.read(stockServiceCreatorProvider) != null && held.contains(WorkspacePermission.manageServices);
    final chosen = await showDialog<_Choice>(context: context, builder: (dialog) => _dialog(dialog, context, candidates, mayCreate));
    if (chosen == null || !context.mounted) return false;
    final saved = chosen.brandNew ? await _newItem(context, workspaceId) : await _existing(context, workspaceId, chosen.service!);
    if (saved) _ref.invalidate(stockItemsProvider(workspaceId));
    return saved;
  }

  Widget _dialog(BuildContext dialog, BuildContext page, List<StockItem> candidates, bool mayCreate) {
    final l10n = page.l10n;
    return SimpleDialog(
      key: const ValueKey('stock-item-add-dialog'),
      title: Text(l10n.stockItemAddTitle),
      children: [
        if (mayCreate)
          SimpleDialogOption(
            key: const ValueKey('stock-item-new'),
            onPressed: () => Navigator.of(dialog).pop((brandNew: true, service: null)),
            child: Text(l10n.stockItemNewOption),
          ),
        if (candidates.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 8), child: Text(l10n.stockItemAddIntro)),
          for (final c in candidates)
            SimpleDialogOption(
              key: ValueKey('stock-item-candidate-${c.id}'),
              onPressed: () => Navigator.of(dialog).pop((brandNew: false, service: c)),
              child: Text(c.name),
            ),
        ] else if (!mayCreate)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stockItemAddNone, key: const ValueKey('stock-item-add-none')),
                TextButton(
                  key: const ValueKey('stock-item-add-services'),
                  onPressed: () {
                    Navigator.of(dialog).pop();
                    unawaited(page.push('/services'));
                  },
                  child: Text(l10n.stockItemAddOpenServices),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<bool> _existing(BuildContext context, String workspaceId, StockItem service) => showStockItemEditor(
    context,
    _ref.read(stockConfigCommandsProvider),
    workspaceId: workspaceId,
    itemId: service.id,
    itemName: service.name,
    options: (lots: _ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockLots), keep: true, groups: itemGroupsIfOn(_ref)),
  );

  Future<bool> _newItem(BuildContext context, String workspaceId) async {
    final creator = _ref.read(stockServiceCreatorProvider);
    if (creator == null) return false;
    try {
      final vat = await creator.vatChoices(workspaceId);
      final places = await _ref.read(stockPlaceConfigsProvider(workspaceId).future);
      if (!context.mounted) return false;
      return await showNewStockItemSheet(
        context,
        (creator: creator, commands: _ref.read(stockConfigCommandsProvider), registry: _ref.read(stockRegistryProvider)),
        workspaceId: workspaceId,
        choices: (
          vat: vat,
          places: places,
          separator: _ref.read(stockAddressSeparatorProvider),
          currency: _ref.read(currentWorkspaceProvider).value?.currencyCode ?? '',
          unit: _ref.read(stockWeighedGoodsProvider) ? 'kg' : 'piece',
        ),
      );
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the new item sheet could not read what it needs: $e', stackTrace: st);
      if (context.mounted) AppSnack.error(context, context.l10n.stockReadFailed);
      return false;
    }
  }
}
