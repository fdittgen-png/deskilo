// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4471 -- the units a form of the money feature offers to PICK from for [workspaceId]: the business's units of measure that are
// not archived while the units feature is on, the six of before while it is off. The composition root (lib/app) wires them
// behind it (the money feature never imports the stock); with nothing wired none is offered.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/line_unit.dart';

final pickableUnitsProvider = Provider.family<List<LineUnit>, String>((ref, workspaceId) => const <LineUnit>[]);
