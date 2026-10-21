// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — what the task recorder may say happened, and nothing else.
//
// A recorded step names a registered SURFACE, a registered ACTION on it
// and, for a command, a registered OUTCOME. All three are stable string
// identifiers with a version, so a recording made today still reads the
// same after a screen is redesigned: the identity of a step is never a
// tap coordinate, a widget address, a localised button label or a route
// string with ids in it.
//
// The registry is finite and lives in code. A recording that names an
// action this build does not know is not executed or guessed at: the
// codec turns that step into an "unrecorded" step and marks the
// recording as not runnable (task_recording_codec.dart). Remote input
// can never add an action, a payload field or an outcome detector.
//
// No shared guidance action catalogue existed when this was written
// (#1853 shipped the help-host inventory only; tankstellen#4480 is
// open), so the identifiers here ARE the shared seam: #1866 (Word),
// #1867 (guided tasks) and #1872 (packages) read them from this file
// rather than copying them.

import 'package:deskilo_task_recording/action_catalogue.dart';

import 'recording_reference.dart';
import 'registry_admin.dart';
import 'registry_calendar.dart';
import 'registry_ui.dart';
import 'safe_payload.dart';
import 'workspace_feature_keys.dart';

export 'package:deskilo_task_recording/action_catalogue.dart';
export 'registry_admin.dart' hide adminActionSpecs, adminOutcomeSpecs;
export 'registry_calendar.dart' hide calendarActionSpecs, calendarOutcomeSpecs;
export 'registry_ui.dart' hide uiActionSpecs, uiOutcomeSpecs;
export 'ui_vocabulary.g.dart';
export 'workspace_feature_keys.dart';


/// The surfaces of the first instrumented task: booking a place.
abstract final class RecorderSurfaces {
  static const reserve = 'reservations.reserve';
  static const bookingSheet = 'reservations.booking_sheet';
  static const reservationDetail = 'reservations.reservation_detail';

  /// #1881 A — my own reservation's sheet: check in, check out, cancel.
  static const myReservation = 'reservations.my_reservation';

  /// #1884 A — the workspace's feature switches.
  static const workspaceFeatures = 'workspace.features';
  /// #1881 B — the calendar (the hub, or the classic month calendar).
  static const calendar = 'calendar.view';

  /// #1881 B — the decisions a member is asked for, on the calendar.
  static const eventDecisions = 'events.decisions';

  /// #1884 B — the role matrix, the roles a space defines, their holders.
  static const roles = 'workspace.roles';

  /// #1884 B — the validation rules.
  static const validationRules = 'events.validation_rules';
  static const recorderControls = 'recorder.controls';

  /// #2142 — any screen, through the generic layer.
  static const anyScreen = 'ui.any';
}

/// Action identifiers, so call sites do not spell strings.
abstract final class RecorderActions {
  static const openReserve = 'reservations.open_reserve';
  static const selectDate = 'reservations.select_date';
  static const selectPeriod = 'reservations.select_period';
  static const switchView = 'reservations.switch_view';
  static const selectResource = 'reservations.select_resource';
  static const changeBookingField = 'reservations.change_booking_field';
  static const confirmBooking = 'reservations.confirm_booking';
  static const cancelReview = 'reservations.cancel_review';
  static const viewDetails = 'reservations.view_details';
  static const back = 'navigation.back';
  static const recorderControl = 'recorder.control';

  // #1881 A — the rest of the reservation surfaces.
  static const selectLevel = 'reservations.select_level';
  static const checkIn = 'reservations.check_in';
  static const checkOut = 'reservations.check_out';
  static const cancelReservation = 'reservations.cancel_reservation';
  static const closeMyReservation = 'reservations.close_my_reservation';

  // #1881 B — the calendar and the decisions on it.
  static const calendarSwitchView = 'calendar.switch_view';
  static const calendarMove = 'calendar.move';
  static const calendarSelectDay = 'calendar.select_day';
  static const calendarFilterKind = 'calendar.filter_kind';
  static const calendarChooseWhose = 'calendar.choose_whose';
  static const calendarOpenItem = 'calendar.open_item';
  static const calendarCancelReservation = 'calendar.cancel_reservation';
  static const decideEvent = 'events.decide';

  // #2142 — the generic layer, on any screen.
  static const uiOpenScreen = 'ui.open_screen';
  static const uiTap = 'ui.tap';
  static const uiCommitField = 'ui.commit_field';
  static const uiCommand = 'ui.command';
  static const uiOpenWindow = 'ui.open_window';
  static const uiCloseWindow = 'ui.close_window';

  // #1884 A — management forms.
  static const switchFeature = 'workspace.switch_feature';
  static const declineOptIn = 'workspace.decline_opt_in';

  // #1884 B — roles and validation rules.
  static const togglePermission = 'workspace.toggle_permission';
  static const saveRole = 'workspace.save_role';
  static const giveRole = 'workspace.give_role';
  static const cancelRoleEdit = 'workspace.cancel_role_edit';
  static const saveValidationRule = 'events.save_validation_rule';
  static const cancelValidationRule = 'events.cancel_validation_rule';
}

/// Outcome identifiers.
abstract final class RecorderOutcomes {
  static const bookingConfirmed = 'booking.confirmed';
  static const bookingRequested = 'booking.requested';
  static const seriesBooked = 'booking.series_booked';
  static const bookingRefused = 'booking.refused';
  static const bookingUnknown = 'booking.unknown';

  // #1881 A — my own reservation's commands.
  static const checkedIn = 'reservation.checked_in';
  static const checkedOut = 'reservation.checked_out';
  static const cancelled = 'reservation.cancelled';
  static const reservationRefused = 'reservation.refused';
  static const reservationUnknown = 'reservation.unknown';

  // #1881 B — a decision asked of the member.
  static const eventDecided = 'event.decided';
  static const eventNotConfirmed = 'event.not_confirmed';

  // #2142 — a guarded command's real result.
  static const commandDone = 'command.done';
  static const commandPending = 'command.pending';
  static const commandRefused = 'command.refused';
  static const commandUnknown = 'command.unknown';

  // #1884 A — a setting's save.
  static const settingSaved = 'setting.saved';
  static const settingNotSaved = 'setting.not_saved';

  /// Sent, but no answer anybody can vouch for (a reload that failed).
  static const settingUnknown = 'setting.unknown';
  // #1884 B — held for a decision, or no answer to vouch for.
  static const settingPending = 'setting.pending';
}

const Set<String> _bookingOutcomes = {
  RecorderOutcomes.bookingConfirmed,
  RecorderOutcomes.bookingRequested,
  RecorderOutcomes.seriesBooked,
  RecorderOutcomes.bookingRefused,
  RecorderOutcomes.bookingUnknown,
};

/// The registry this build records against.
const ActionRegistry recorderRegistry = ActionRegistry(
  contractVersion: actionContractVersion,
  surfaces: [
    RecorderSurface(RecorderSurfaces.reserve),
    RecorderSurface(RecorderSurfaces.bookingSheet),
    RecorderSurface(RecorderSurfaces.reservationDetail),
    RecorderSurface(RecorderSurfaces.myReservation),
    RecorderSurface(RecorderSurfaces.workspaceFeatures),
    RecorderSurface(RecorderSurfaces.calendar),
    RecorderSurface(RecorderSurfaces.eventDecisions),
    RecorderSurface(RecorderSurfaces.roles),
    RecorderSurface(RecorderSurfaces.validationRules),
    RecorderSurface(RecorderSurfaces.recorderControls, recorderControl: true),
    RecorderSurface(RecorderSurfaces.anyScreen),
    RecorderSurface('navigation.any'),
  ],
  actions: [
    ActionSpec(
      RecorderActions.openReserve,
      surface: RecorderSurfaces.reserve,
      kind: ActionKind.navigate,
    ),
    ActionSpec(
      RecorderActions.selectDate,
      surface: RecorderSurfaces.reserve,
      kind: ActionKind.select,
      payloadFields: {'date_relation'},
    ),
    ActionSpec(
      RecorderActions.selectPeriod,
      surface: RecorderSurfaces.reserve,
      kind: ActionKind.select,
      payloadFields: {'period'},
    ),
    ActionSpec(
      RecorderActions.switchView,
      surface: RecorderSurfaces.reserve,
      kind: ActionKind.select,
      payloadFields: {'view_mode'},
    ),
    ActionSpec(
      RecorderActions.selectResource,
      surface: RecorderSurfaces.reserve,
      kind: ActionKind.select,
      payloadFields: {'view_mode', 'resource_kind'},
    ),
    ActionSpec(
      RecorderActions.changeBookingField,
      surface: RecorderSurfaces.bookingSheet,
      kind: ActionKind.fieldCommit,
      targets: {'for_whom', 'repeat', 'check_in', 'time', 'accessories'},
    ),
    ActionSpec(
      RecorderActions.confirmBooking,
      surface: RecorderSurfaces.bookingSheet,
      kind: ActionKind.submit,
      payloadFields: {'for_whom', 'repeat', 'check_in'},
      outcomes: _bookingOutcomes,
    ),
    ActionSpec(
      RecorderActions.cancelReview,
      surface: RecorderSurfaces.bookingSheet,
      kind: ActionKind.cancel,
    ),
    ActionSpec(
      RecorderActions.viewDetails,
      surface: RecorderSurfaces.reservationDetail,
      kind: ActionKind.open,
    ),
    ActionSpec(
      RecorderActions.back,
      surface: 'navigation.any',
      kind: ActionKind.back,
    ),
    ActionSpec(
      RecorderActions.selectLevel,
      surface: RecorderSurfaces.reserve,
      kind: ActionKind.select,
    ),
    ActionSpec(
      RecorderActions.checkIn,
      surface: RecorderSurfaces.myReservation,
      kind: ActionKind.submit,
      outcomes: {
        RecorderOutcomes.checkedIn,
        RecorderOutcomes.reservationRefused,
        RecorderOutcomes.reservationUnknown,
      },
    ),
    ActionSpec(
      RecorderActions.checkOut,
      surface: RecorderSurfaces.myReservation,
      kind: ActionKind.submit,
      outcomes: {
        RecorderOutcomes.checkedOut,
        RecorderOutcomes.reservationRefused,
        RecorderOutcomes.reservationUnknown,
      },
    ),
    ActionSpec(
      RecorderActions.cancelReservation,
      surface: RecorderSurfaces.myReservation,
      kind: ActionKind.submit,
      outcomes: {
        RecorderOutcomes.cancelled,
        RecorderOutcomes.reservationRefused,
        RecorderOutcomes.reservationUnknown,
      },
    ),
    ActionSpec(
      RecorderActions.closeMyReservation,
      surface: RecorderSurfaces.myReservation,
      kind: ActionKind.cancel,
    ),
    ActionSpec(
      RecorderActions.switchFeature,
      surface: RecorderSurfaces.workspaceFeatures,
      kind: ActionKind.submit,
      targets: workspaceFeatureKeys,
      payloadFields: {'switch_to'},
      outcomes: {
        RecorderOutcomes.settingSaved,
        RecorderOutcomes.settingNotSaved,
        RecorderOutcomes.settingUnknown,
      },
    ),
    ActionSpec(
      RecorderActions.declineOptIn,
      surface: RecorderSurfaces.workspaceFeatures,
      kind: ActionKind.cancel,
    ),
    ...calendarActionSpecs,
    ...uiActionSpecs,
    ...adminActionSpecs,
    ActionSpec(
      RecorderActions.recorderControl,
      surface: RecorderSurfaces.recorderControls,
      kind: ActionKind.select,
    ),
  ],
  outcomes: [
    OutcomeSpec(
      RecorderOutcomes.bookingConfirmed,
      state: ObservationState.confirmed,
      payloadFields: {'check_in'},
    ),
    OutcomeSpec(
      RecorderOutcomes.bookingRequested,
      state: ObservationState.pending,
    ),
    OutcomeSpec(
      RecorderOutcomes.seriesBooked,
      state: ObservationState.confirmed,
      payloadFields: {'series_result'},
    ),
    OutcomeSpec(
      RecorderOutcomes.bookingRefused,
      state: ObservationState.refused,
      payloadFields: {'refusal'},
    ),
    OutcomeSpec(
      RecorderOutcomes.bookingUnknown,
      state: ObservationState.outcomeUnknown,
    ),
    OutcomeSpec(RecorderOutcomes.checkedIn, state: ObservationState.confirmed),
    OutcomeSpec(RecorderOutcomes.checkedOut, state: ObservationState.confirmed),
    OutcomeSpec(RecorderOutcomes.cancelled, state: ObservationState.confirmed),
    OutcomeSpec(
      RecorderOutcomes.reservationRefused,
      state: ObservationState.refused,
      payloadFields: {'refusal'},
    ),
    OutcomeSpec(
      RecorderOutcomes.reservationUnknown,
      state: ObservationState.outcomeUnknown,
    ),
    OutcomeSpec(
      RecorderOutcomes.settingSaved,
      state: ObservationState.confirmed,
    ),
    OutcomeSpec(
      RecorderOutcomes.settingNotSaved,
      state: ObservationState.refused,
      payloadFields: {'refusal'},
    ),
    OutcomeSpec(
      RecorderOutcomes.settingUnknown,
      state: ObservationState.outcomeUnknown,
    ),
    ...calendarOutcomeSpecs,
    ...uiOutcomeSpecs,
    ...adminOutcomeSpecs,
  ],
  prerequisites: [
    PrerequisiteSpec('signed_in'),
    PrerequisiteSpec('workspace_member'),
    PrerequisiteSpec(
      'starts_on',
      values: {
        RecorderSurfaces.reserve,
        RecorderSurfaces.bookingSheet,
        RecorderSurfaces.reservationDetail,
        RecorderSurfaces.myReservation,
        RecorderSurfaces.workspaceFeatures,
        RecorderSurfaces.calendar,
        RecorderSurfaces.roles,
        RecorderSurfaces.validationRules,
      },
    ),
    PrerequisiteSpec('bookable_place'),
  ],
  safeFields: safeFields,
  acceptsPage: isGuideDestination,
);
