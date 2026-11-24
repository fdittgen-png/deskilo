// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B), #4379 -- what the put-away of a delivery reads before its sheet opens: the places, the stock
// configuration and variants of each delivered line's item, and which lines are tagged piece by piece.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/item_groups.dart';
import '../domain/put_away_progress.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';
import '../domain/stock_receiving.dart';
import '../domain/stock_variants.dart';
import 'put_away_tags.dart';

/// What the put-away asks of the stock and of the business, read from the
/// providers by the pane and handed over whole.
class PutAwayServices {
  const PutAwayServices({
    required this.commands,
    required this.config,
    required this.queries,
    required this.currency,
    this.groups,
  });

  final StockReceivingCommands commands;

  /// #4379 -- where an item's effective tag mode is read; null when the business uses no tags.
  final ItemGroups? groups;
  final StockConfigCommands config;
  final StockQueries queries;

  /// The business's currency, for the rate of an order in another one.
  final String currency;
}

/// What the form needs of the stock side, read before it opens.
class PutAwayContext {
  const PutAwayContext({
    required this.places,
    required this.items,
    required this.variants,
    required this.currency,
    this.perUnit = const {},
  });

  final List<StockPlace> places;

  /// The stock configuration of the item each line names (by line number),
  /// when it is a stock item the business keeps.
  final Map<int, StockItemConfig> items;
  final Map<int, List<StockVariant>> variants;

  /// The business's currency, for the rate of an order in another one.
  final String currency;

  /// #4379 -- the lines whose item is tagged piece by piece: one tag per piece is read as it is put away.
  final Set<int> perUnit;
}

/// Reads what the form needs for [lines]; null when the stock side could not
/// be read (the caller says so).
Future<PutAwayContext?> loadPutAwayContext(
  BuildContext context,
  PutAwayServices services, {
  required String workspaceId,
  required List<DeliveredLineProgress> lines,
}) async {
  final config = services.config;
  return guardRead<PutAwayContext?>(
    domain: 'stock',
    message: 'the put-away could not read the stock side',
    read: () async {
      final places = await services.queries.places(workspaceId);
      final items = <int, StockItemConfig>{};
      final variants = <int, List<StockVariant>>{};
      final perUnit = <int>{};
      for (final l in lines) {
        final id = l.serviceId;
        if (id == null) continue;
        final item = await config.item(workspaceId, id);
        if (item == null || !item.stockable) continue;
        items[l.lineNo] = item;
        variants[l.lineNo] = [for (final v in await config.variants(workspaceId, id)) if (v.active) v];
        if (await tagsEachPiece(services.groups, workspaceId, id)) perUnit.add(l.lineNo);
      }
      return PutAwayContext(places: places, items: items, variants: variants, currency: services.currency, perUnit: perUnit);
    },
    fallback: (_) {
      if (context.mounted) AppSnack.error(context, context.l10n.stockReadFailed);
      return null;
    },
  );
}
