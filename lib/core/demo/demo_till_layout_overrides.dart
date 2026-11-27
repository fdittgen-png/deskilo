// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the Demo's till layouts: one store for the session, seeded with the front counter and the bakery counter.
// #4466 -- and its till board, connected at the front counter.
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/providers/till_layout_providers.dart';
import '../devices/connected_boards_provider.dart';
import 'data/demo_till_board.dart';
import 'data/demo_till_layouts.dart';

List<Override> demoTillLayoutOverrides() => [
  tillLayoutPortProvider.overrideWithValue(DemoTillLayouts()..seed()),
  connectedTillBoardsProvider.overrideWithValue(AsyncData([demoTillBoard()])),
];
