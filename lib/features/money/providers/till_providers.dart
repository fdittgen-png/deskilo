// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/counter_till.dart';

/// #4366 -- the till's server: readiness, a priced draft and the one command that makes the sale. The app wires the
/// live one (`tillPortFromApp`); the Demo and the tests replace it.
final tillPortProvider = Provider<TillPort>((ref) => throw UnimplementedError('the till port is wired by the app'));

/// #4366 -- whether the country allows this business's till to sell, and why not when it does not. Read again when the
/// screen opens: a country's operation can move between two shifts.
final tillReadinessProvider = FutureProvider.autoDispose.family<TillReadiness, String>(
  (ref, workspaceId) => ref.watch(tillPortProvider).readiness(workspaceId),
  retry: (_, _) => null,
);
