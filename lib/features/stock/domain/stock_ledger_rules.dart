// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- the rules and reads of the stock ledger (stock_ledger.dart) that need nothing but what it shows: a
// delivery's allocation put away (0840), a reorder point and what a site holds (0856), and where an item is
// (0926). Pure, as the ledger is; the SQL they mirror is cited at each.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'stock_config.dart';
import 'stock_ledger.dart';
import 'stock_page.dart';
import 'stock_receiving.dart';
import 'stock_sites.dart';
import 'stock_where_is.dart';

final _quantityText = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

/// The ledger's rules that read it and write nothing.
extension StockLedgerRules on StockLedger {
  /// The movements of [itemId] (of its lot [lotId]) up to [at], newest first.
  List<StockMovementRow> movesOf(String itemId, {String? lotId, DateTime? at}) => [
    for (final m in movements)
      if (m.itemId == itemId && (lotId == null || m.lotId == lotId) && (at == null || !m.occurredAt.isAfter(at))) m,
  ];

  /// Where [moves] left the goods: each adds to the place it went to and takes from the one it left, the server's
  /// own places included (0926 stock_where_is_v1 replays the movements the same way). A place with nothing is left
  /// out; the real places come first, then by code.
  List<WhereIsPlace> whereIs(List<StockMovementRow> moves) {
    final held = <String, ({String place, String? lotId, String? lotCode, ExactQuantity quantity})>{};
    void add(StockMovementRow m, String place, ExactQuantity q) {
      final key = '$place|${m.lotId ?? ''}';
      held[key] = (place: place, lotId: m.lotId, lotCode: m.lotCode, quantity: (held[key]?.quantity ?? ExactQuantity.zero) + q);
    }

    for (final m in moves) {
      add(m, m.toLocationId, m.quantity);
      add(m, m.fromLocationId, ExactQuantity.zero - m.quantity);
    }
    return [
      for (final h in held.values)
        if (h.quantity != ExactQuantity.zero)
          WhereIsPlace(
            locationId: h.place,
            locationCode: places[h.place]?.code ?? '',
            locationName: places[h.place]?.name ?? '',
            locationKind: places[h.place]?.kind ?? '',
            isVirtual: places[h.place]?.virtual ?? false,
            quantity: h.quantity,
            lotId: h.lotId,
            lotCode: h.lotCode,
          ),
    ]..sort((a, b) {
      if (a.isVirtual != b.isVirtual) return a.isVirtual ? 1 : -1;
      return a.locationCode.compareTo(b.locationCode);
    });
  }

  // ── a delivery put away (0840 stock_put_away_apply) ──────────────────────

  /// One allocation [i] of a put-away as 0840 stock_put_away_apply reads it, in its order: a stock item
  /// (0840:330), the order line's unit by its exact factor (0840:332-338), a quantity above zero (0840:340-345),
  /// never more than [left] of what the line received, earlier allocations counted (0840:347-351), a real place of the
  /// business (0840:372-374), a variant when the item has some (0840:368-369), and the lot code and the date its
  /// tracking asks for (0840:391-399). Answers the quantity in the line's unit and in the inventory unit.
  ({ExactQuantity entered, ExactQuantity inventory}) putAwayPart(
    int i, {
    required StockItemConfig? item,
    required String unit,
    required PutAwayAllocation part,
    required ExactQuantity left,
    required bool hasVariants,
  }) {
    if (item == null || !item.stockable) throw StockConfigRefused('allocations[$i].line', StockRefusal.itemNotStocked);
    final factor = configFactor(item, unit);
    if (factor == null) throw StockConfigRefused('allocations[$i].line', StockRefusal.unitUnmapped);
    final qty = ExactQuantity.tryParse(part.quantity).value;
    if (qty == null || qty <= ExactQuantity.zero) throw StockConfigRefused('allocations[$i].quantity', StockRefusal.quantityInvalid);
    // in the inventory unit, as the server records it: round(q * num / den, 6) (0840:355)
    final inventory = qty.scaled(factor.num, factor.den, round: true).value;
    if (inventory == null || inventory <= ExactQuantity.zero) {
      throw StockConfigRefused('allocations[$i].quantity', StockRefusal.quantityInvalid);
    }
    if (qty > left) throw StockConfigRefused('allocations[$i].quantity', StockRefusal.overAllocated);
    if (!isReal(part.locationId)) throw StockConfigRefused('allocations[$i].location_id', StockRefusal.locationForeign);
    if (hasVariants && part.variantId == null) throw StockConfigRefused('allocations[$i].variant_id', StockRefusal.variantRequired);
    if ((item.tracking == 'lot' || item.tracking == 'expiry') && (part.lotCode ?? '').isEmpty) {
      throw StockConfigRefused('allocations[$i].lot.code', StockRefusal.lotCodeRequired);
    }
    if (item.tracking == 'expiry' && part.expiresOn == null) {
      throw StockConfigRefused('allocations[$i].lot.expires_on', StockRefusal.expiryRequired);
    }
    return (entered: qty, inventory: inventory);
  }

  // ── reorder points (0856) ────────────────────────────────────────────────

  /// A quantity of a reorder point's payload as 0856:358-365 reads it: absent keeps [fallback], empty clears, any
  /// other text is a quantity of up to twelve digits and six decimals.
  static ExactQuantity? reorderQuantityOf(Map<String, Object?> point, String key, ExactQuantity? fallback) {
    if (!point.containsKey(key)) return fallback;
    final text = (point[key] as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    if (!_quantityText.hasMatch(text)) throw StockConfigRefused(key, StockRefusal.quantityInvalid);
    return ExactQuantity.parse(text);
  }

  /// What to order when an item is low (0856:441-446): a level; then a quantity above zero or a level to order up
  /// to above the point, not both.
  static ExactQuantity reorderRule(ExactQuantity? level, ExactQuantity? quantity, ExactQuantity? target) {
    if (level == null) throw const StockConfigRefused('reorder_point', StockRefusal.quantityInvalid);
    if (quantity != null && target != null) throw const StockConfigRefused('target_quantity', StockRefusal.quantityAndTarget);
    if (quantity != null && quantity.compareTo(ExactQuantity.zero) <= 0) {
      throw const StockConfigRefused('reorder_quantity', StockRefusal.quantityInvalid);
    }
    if (target != null && target.compareTo(level) <= 0) throw const StockConfigRefused('target_quantity', StockRefusal.targetBelowPoint);
    return level;
  }

  /// What [itemId] holds in all at the site [siteId] and every place inside it, loose and in lots (0856, what is
  /// low is read from the whole site).
  ExactQuantity heldInSite(String itemId, String siteId) {
    var total = ExactQuantity.zero;
    for (final r in onHand(itemId: itemId)) {
      if (stockSiteOf(r.locationId, places.values) == siteId) total = total + r.quantity;
    }
    return total;
  }
}
