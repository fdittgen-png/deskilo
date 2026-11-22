// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 -- the line of the low-stock notice: which item, at which site (by its address), what is on
// hand and the reorder point, in the item's unit; "back above its point" once it ended. The quantities
// are exact text from the ledger, shown as the stock screens show them.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/workspace_event.dart';

String _quantity(AppLocalizations l10n, Object? text, String unit) {
  final parsed = text is String ? ExactQuantity.tryParse(text).value : null;
  return parsed == null ? '' : l10n.stockQuantityWithUnit(parsed.text, unit);
}

/// The line of a `stock_low` [event]; [names] carries `item:`, `unit:` and `place:` keys.
String stockLowLine(AppLocalizations l10n, WorkspaceEvent event, Map<String, String> names) {
  final item = '${event.payload['item_id'] ?? ''}';
  final site = '${event.payload['site_id'] ?? ''}';
  final unit = names['unit:$item'] ?? '';
  final line = l10n.eventStockLow(
    names['item:$item'] ?? l10n.eventStockLowItemFallback,
    names['place:$site'] ?? l10n.eventStockLowSiteFallback,
    _quantity(l10n, event.payload['on_hand'], unit),
    _quantity(l10n, event.payload['reorder_point'], unit),
  );
  return event.payload.containsKey('ended') ? '$line · ${l10n.eventStockLowEnded}' : line;
}
