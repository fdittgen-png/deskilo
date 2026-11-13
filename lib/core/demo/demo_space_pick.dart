// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3797 — one store per Demo space, and the one the scope is looking at:
// a space never reads another's records.
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../features/workspace/providers/workspace_providers.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_trade_city_seed.dart';
import 'seed/demo_twin_seed.dart';

/// One value for each of the Demo's seven spaces.
typedef DemoSpaces<T> = ({
  T home,
  T leipzig,
  T london,
  T newYork,
  T zurich,
  T milan,
  T twin,
});

/// The one of [spaces] that belongs to the space being looked at: the main
/// space's while no space is open yet.
T demoPickSpace<T>(Ref ref, DemoSpaces<T> spaces) =>
    switch (ref.watch(currentWorkspaceProvider).value?.id) {
      demoSecondSpaceId => spaces.leipzig,
      demoLondonSpaceId => spaces.london,
      demoNewYorkSpaceId => spaces.newYork,
      demoZurichSpaceId => spaces.zurich,
      demoMilanSpaceId => spaces.milan,
      demoTwinSpaceId => spaces.twin,
      _ => spaces.home,
    };
