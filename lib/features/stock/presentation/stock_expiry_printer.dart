// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- what the stock needs of the report engine to print the expiry report: quick view, save or share through the
// workspace's report system with the layout the business edits. The stock never imports the money feature: the app wires
// this port (lib/app/stock_expiry_print.dart), as it does for a new item's service.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stock_expiry.dart';

abstract interface class StockExpiryPrinter {
  /// Prints [report], read for [query], through the report engine.
  Future<void> print(BuildContext context, WidgetRef ref, {required ExpiryReport report, required ExpiryQuery query});
}
