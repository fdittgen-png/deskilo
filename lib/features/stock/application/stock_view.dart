// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- what the Stock screen is looking at: the tab and the filters.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two lists of the Stock screen.
enum StockTab { onHand, movements }

/// The tab and the item and place filters chosen.
class StockView {
  const StockView({this.tab = StockTab.onHand, this.itemId, this.locationId});

  final StockTab tab;
  final String? itemId;
  final String? locationId;

  bool get filtered => itemId != null || locationId != null;
}

/// The Stock screen's view of itself.
class _StockViewNotifier extends Notifier<StockView> {
  @override
  StockView build() => const StockView();

  void showTab(StockTab tab) =>
      state = StockView(tab: tab, itemId: state.itemId, locationId: state.locationId);

  void filter({String? itemId, String? locationId}) =>
      state = StockView(tab: state.tab, itemId: itemId, locationId: locationId);
}

final stockViewProvider =
    NotifierProvider.autoDispose<_StockViewNotifier, StockView>(
      _StockViewNotifier.new,
    );
