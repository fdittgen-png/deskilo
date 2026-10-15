// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the Reserve hub tells the task recorder (#1865, #1881): the steps a
// person takes on it. One place for the action ids and their payloads, so the
// screen, its header and its views carry none of them (#2494).




import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/workspace_time.dart';
import '../../../task_recorder/application/booking_observation.dart'
    show dateRelation, dayValues, periodOf, periodValues, resourceValues;
import '../../../task_recorder/domain/action_registry.dart'
    show RecorderActions;
import '../../../task_recorder/presentation/recorder_seam.dart';

class ReserveHubRecorder {
  const ReserveHubRecorder(this._ref);

  final WidgetRef _ref;

  /// The form was entered.
  void openedReserve() => recordTaskStep(_ref, RecorderActions.openReserve);

  /// The view switched to [mode] (`plan`, `list`, `day`, `week`, `month`).
  void switchedView(String mode) => recordTaskStep(
      _ref, RecorderActions.switchView,
      payload: {'view_mode': mode});

  /// The browsed day moved to [day].
  void selectedDate(DateTime day, DateTime today) =>
      recordTaskStep(_ref, RecorderActions.selectDate,
          payload: {'date_relation': dateRelation(day, today)},
          values: dayValues(day));

  /// A canonical window (Morning, Afternoon, Full day, a chip) was picked.
  void selectedPeriod(DateTime start, DateTime end) => recordTaskStep(
      _ref, RecorderActions.selectPeriod,
      payload: {
        'period': periodOf(
            startHour: WorkspaceTime.wall(start).hour,
            length: end.difference(start)),
      },
      values: periodValues(start, end));

  /// A hand-picked from→to window.
  void selectedCustomPeriod(DateTime from, DateTime to) => recordTaskStep(
      _ref, RecorderActions.selectPeriod,
      payload: const {'period': 'custom'}, values: periodValues(from, to));

  void selectedLevel() => recordTaskStep(_ref, RecorderActions.selectLevel);

  /// A seat was tapped in the [mode] view (`plan` or `list`).
  void selectedSeat(String mode, String seatName) =>
      recordTaskStep(_ref, RecorderActions.selectResource,
          payload: {'view_mode': mode, 'resource_kind': 'desk'},
          values: resourceValues(seatName));
}
