// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the units a line of a quote or an invoice may be sold in besides the four it always offers, for [workspaceId].
// The composition root (lib/app) wires the business's units behind it (the money feature never imports the stock); with
// nothing wired no unit is offered and the picker is what it always was.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/line_unit.dart';

final lineUnitsProvider = Provider.family<AsyncValue<List<LineUnit>>, String>((ref, workspaceId) => const AsyncData(<LineUnit>[]));
