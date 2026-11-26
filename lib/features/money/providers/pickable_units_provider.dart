// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4471 -- the units a form of the money feature offers to PICK from for [workspaceId]: the business's units of measure that are
// not archived while the units feature is on, the six of before while it is off. The composition root (lib/app) wires them
// behind it (the money feature never imports the stock); with nothing wired none is offered.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/line_unit.dart';

final pickableUnitsProvider = Provider.family<List<LineUnit>, String>((ref, workspaceId) => const <LineUnit>[]);

/// One item of one business.
typedef ItemUnitsKey = ({String workspaceId, String itemId});

/// #4479 -- the units an order line of a STOCKED item may be in: the ones that convert to the item's inventory unit (its own, its own
/// conversions, the business's general ones). Null when the item is not restricted (not stocked, or nothing wired): the business's
/// units then. The composition root wires it (the money feature never imports the stock).
final itemOrderUnitsProvider = FutureProvider.autoDispose.family<List<LineUnit>?, ItemUnitsKey>((ref, key) async => null);
