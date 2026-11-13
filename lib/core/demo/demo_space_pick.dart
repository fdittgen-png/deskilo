// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3797 — one store per Demo space, and the one the scope is looking at:
// a space never reads another's records.
// #3867 — one resolver for the open space, shared by every router; an id no
// space owns fails closed.
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../features/workspace/providers/workspace_providers.dart';
import 'demo_spaces.dart';

export 'demo_spaces.dart';

/// The Demo space the scope is looking at: the main space's while no space is
/// open yet; an id no space owns throws.
DemoSpaceKey demoOpenSpace(Ref ref) =>
    DemoSpaceKey.of(ref.watch(currentWorkspaceProvider).value?.id);

/// The one of [spaces] that belongs to the space being looked at.
T demoPickSpace<T>(Ref ref, DemoSpaces<T> spaces) =>
    spaces.at(demoOpenSpace(ref));
