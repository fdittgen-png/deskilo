// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4426 -- today on the business's calendar, date-only: what a new document offers as its date (an issue date, a service
// date, a decision date) whatever the zone of the device. The app wires the business's own calendar (`businessDayFromApp`,
// which moves at the business's midnight); until it does, the clock's UTC date stands in, never the device's.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/business_day.dart';
import '../../../core/time/clock.dart';

final businessDayProvider = Provider<DateTime>((ref) => businessDateOf(ref.watch(clockProvider).now(), null));
