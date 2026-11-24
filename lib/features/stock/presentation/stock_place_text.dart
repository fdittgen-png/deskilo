// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4293 -- a place as a person reads it wherever it appears (the stock, the movements, a transfer's
// route, the places a goods move offers): its ADDRESS (`MAG1-SALES-A03-B02-S4`, the codes of its
// parents with the business's separator), never the bare code of its last level, which repeats
// from bay to bay. A place the lists do not know falls back to the code the answer carries.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stock_config.dart';
import '../providers/stock_providers.dart';

/// A place's own title: its address, then its name when it has one. The system's places (a
/// supplier, a customer, the in-transit place) are their code.
String stockPlaceTitle(StockPlaceConfig p, String separator) {
  final base = p.isAddressable ? stockAddress(p, separator) : p.code;
  return p.name.isEmpty ? base : '$base · ${p.name}';
}

/// The address of each place of [workspaceId] by its id, with the business's separator; empty while
/// the places load or when they could not be read (the screens then show the code they were given).
final stockAddressesProvider = Provider.autoDispose.family<Map<String, String>, String>((ref, workspaceId) {
  final places = ref.watch(stockPlaceConfigsProvider(workspaceId)).value; // empty-ok: a fallback to the code
  final separator = ref.watch(stockAddressSeparatorProvider);
  return {
    if (places != null)
      for (final p in places)
        p.id: p.isAddressable ? stockAddress(p, separator) : p.code,
  };
});
