// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the lots the Demo's till may sell from, as the expiry report holds them (demo_stock_expiry.dart): the oat milk
// has MILK-09, six days past its date (shown, not offered), and MILK-12, four days to go. Any other item has none.
import '../../../features/money/domain/counter_till.dart';

/// #4436 -- the Demo's traced items: the oat milk is tracked by lot, and a sale takes the lot the seller chose (#4366), else the one that expires
/// first and is not expired (MILK-12; MILK-09 is past its date). The gift basket's pieces are of lot BASKET-1; a sale names each piece's tag.
const demoTracedLots = <String, String>{'demo-item-milk': 'MILK-12', 'demo-item-basket': 'BASKET-1'};

/// The milk's two lots in the expiry report: six days past its date, and four days to go.
const _milk09DaysPast = 6;
const _milk12DaysLeft = 4;

/// The Demo's lots, dated from its [clock] (no date without one).
class DemoTillLots implements TillLotsPort {
  const DemoTillLots({this.clock});

  final DateTime Function()? clock;

  @override
  Future<List<TillLot>> lots(String workspaceId, String itemId) async {
    final today = clock?.call();
    return switch (itemId) {
      'demo-item-milk' => [
        TillLot(id: 'demo-lot-milk-09', code: 'MILK-09', quantity: '2', expiresOn: today?.subtract(const Duration(days: _milk09DaysPast)), expired: true),
        TillLot(id: 'demo-lot-milk-12', code: 'MILK-12', quantity: '6', expiresOn: today?.add(const Duration(days: _milk12DaysLeft))),
      ],
      _ => const [],
    };
  }
}
