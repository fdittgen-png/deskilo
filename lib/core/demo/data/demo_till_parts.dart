// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Demo till's pure parts: #4476 -- what it does as the server does (0965, 0966): a line's price is the item's unless
// the right and a reason change it, or a discount within the business's limit; a finalized receipt is printed again as
// its next copy, and the same request answers the same copy (exact, in minor units and millionths). With them the frozen
// line it keeps, a tender with a new state, and the gaps in an offline session's numbers.
import 'dart:math' show pow;

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/money/domain/counter_book.dart';
import '../../../features/money/domain/counter_till.dart';
import '../../../features/money/domain/till_keypad.dart';
import '../../../features/money/domain/till_offline.dart';
import '../../codes/dk_code.dart';

/// A refusal as the server words it: its code, and its reason (and limit) as the JSON detail.
PostgrestException demoTillRefused(String code, String message, {String? reason, int? max}) => PostgrestException(
  message: message,
  code: code,
  details: reason == null ? null : '{"reason":"$reason"${max == null ? '' : ',"max":$max'}}',
);

const _million = 1000 * 1000;

/// The Demo business's `counter.max_discount_percent`, and whether its cashier holds the right to change a price at the
/// till (the Demo's owner does).
class DemoTillPricing {
  const DemoTillPricing({this.maxDiscountPercent = demoMaxDiscountPercent, this.mayChangePrice = true, this.deposits = const {'demo-item-bottle'}});

  /// #4478 -- the items some item is sold with as its deposit: the syrup's glass bottle (#4487).
  final Set<String> deposits;

  static const demoMaxDiscountPercent = 10;
  final int maxDiscountPercent;
  final bool mayChangePrice;
}

/// The unit price of [l] in minor units: the item's [listed] one, another with the right and a reason, or a discount
/// within the [pricing]'s limit; refused as the server refuses it.
/// #4478 -- what a line amounts to in minor units: [unitPrice] times its quantity, negated for a deposit brought back,
/// refused as the server refuses a return ([index] names the line).
int demoTillLineAmount(TillLine l, int unitPrice, int amount, DemoTillPricing pricing, {required int index}) {
  if (!l.returned) return amount;
  // as the server says it: the missing line in the refusal's detail
  if (!pricing.deposits.contains(l.itemId)) {
    throw PostgrestException(message: 'receipt_essentials_missing', code: DkCode.dkl02, details: 'line_${index}_returned');
  }
  if (l.price != null || l.discount != null) {
    throw PostgrestException(message: 'receipt_essentials_missing', code: DkCode.dkl02, details: 'line_${index}_returned_price');
  }
  if (!pricing.mayChangePrice) throw demoTillRefused(DkCode.dkn01, 'not allowed to return a deposit', reason: 'deposit_return');
  return -amount;
}

int demoTillUnitPrice(TillLine l, int listed, DemoTillPricing pricing, {required int minorDigits}) {
  final maxDiscountPercent = pricing.maxDiscountPercent;
  final discount = l.discount;
  if (discount != null) {
    if (l.price != null) throw demoTillRefused(DkCode.dkl02, 'a discount or a price, not both', reason: 'price_and_discount');
    final pct = tillMillionths(discount);
    if (pct == null || pct <= 0 || pct > 100 * _million) throw demoTillRefused(DkCode.dkl02, 'a discount is a percentage', reason: 'discount');
    if (pct > maxDiscountPercent * _million) {
      throw demoTillRefused(DkCode.dkn01, 'beyond the limit', reason: 'discount_limit', max: maxDiscountPercent);
    }
    return (listed * (100 * _million - pct) / (100 * _million)).round();
  }
  final price = l.price == null ? null : tillMillionths(l.price!);
  if (price == null) return listed;
  final minor = (price * pow(10, minorDigits) / _million).round();
  if (minor == listed) return listed;
  if (!pricing.mayChangePrice) throw demoTillRefused(DkCode.dkn01, 'not allowed to change a price', reason: 'price');
  if ((l.priceReason ?? '').trim().isEmpty) throw demoTillRefused(DkCode.dkl02, 'a changed price needs its reason', reason: 'price_reason');
  return minor;
}

/// The copies printed of each receipt, and the copy each request printed.
class DemoTillCopies {
  final Map<String, int> _count = {};
  final Map<String, int> _byRequest = {};

  int copy(String requestId, String receiptId, {required bool finalized}) {
    final again = _byRequest[requestId];
    if (again != null) return again;
    if (!finalized) throw demoTillRefused(DkCode.dkl04, 'only a finalized receipt has copies', reason: 'receipt');
    final n = (_count[receiptId] ?? 0) + 1;
    _count[receiptId] = n;
    return _byRequest[requestId] = n;
  }
}

/// The line a Demo receipt freezes: its gross and tax at [vatPercent], in [currency].
Map<String, Object?> demoTillFrozenLine(TillLine l, int gross, int tax, {required int vatPercent, required String currency}) => {
  'kind': 'goods',
  'label': l.name,
  'amount_cents': gross,
  'vat_percent': vatPercent,
  'commercial': {
    'version': 1,
    'quantity': l.quantity,
    'unit': {'code': l.unit, 'label': l.unit},
    'amounts': {'currency': currency, 'net_minor': '${gross - tax}', 'tax_minor': '$tax', 'gross_minor': '$gross', 'rule': 'half_up_per_line'},
  },
};

/// [t] with a new state, reconciliation or provider reference.
CounterBookTender demoTenderWith(CounterBookTender t, {String? state, String? reconciliation, String? providerRef}) => CounterBookTender(
  id: t.id,
  part: t.part,
  kind: t.kind,
  amountMinor: t.amountMinor,
  state: state ?? t.state,
  reconciliation: reconciliation ?? t.reconciliation,
  providerKey: t.providerKey,
  providerRef: providerRef ?? t.providerRef,
);

/// The numbers missing below the highest one an offline session sent.
List<int> demoOfflineGaps(List<OfflineSaleRow> rows) {
  final seen = {for (final r in rows) r.seq};
  final top = seen.fold<int>(0, (a, b) => a > b ? a : b);
  return [for (var n = 1; n <= top; n++) if (!seen.contains(n)) n];
}
