// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B), #4299 -- what the Stock screen is looking at: the filters (the tab
// is the page: `/stock` or `/stock/movements`).
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two pages of the Stock screen: the balances and the movement log.
enum StockTab { onHand, movements }

/// The item and place filters chosen.
class StockView {
  const StockView({this.itemId, this.locationId});

  final String? itemId;
  final String? locationId;

  bool get filtered => itemId != null || locationId != null;
}

/// The Stock screen's view of itself.
class _StockViewNotifier extends Notifier<StockView> {
  @override
  StockView build() => const StockView();

  void filter({String? itemId, String? locationId}) =>
      state = StockView(itemId: itemId, locationId: locationId);
}

final stockViewProvider =
    NotifierProvider.autoDispose<_StockViewNotifier, StockView>(
      _StockViewNotifier.new,
    );
