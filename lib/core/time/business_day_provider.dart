// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4426 -- today on the active business's calendar, date-only: what a new document offers as its date (an issue date, a
// service date, a decision date) whatever the zone of the device. It moves at the business's midnight. Read here, in
// core, so a feature that offers a date does not import the workspace feature for it.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workspace/providers/business_date_provider.dart';
import 'clock.dart';

final businessDayProvider = Provider<DateTime>(
  (ref) => ref.watch(businessDateOfProvider)(ref.watch(clockProvider).now()),
);
