// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4426 -- the money screens offer today on the active business's calendar. Composed here, where both features are, so
// the money feature does not import the workspace for it.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/time/clock.dart';
import '../features/money/providers/business_day_provider.dart';
import '../features/workspace/providers/business_date_provider.dart';

/// Puts the business's day in a scope's overrides (main.dart, the demo container).
final Override businessDayFromApp = businessDayProvider.overrideWith(
  (ref) => ref.watch(businessDateOfProvider)(ref.watch(clockProvider).now()),
);
