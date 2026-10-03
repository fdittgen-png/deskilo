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

import 'ui_vocabulary.g.dart';
import 'workspace_feature_keys.dart';

export 'ui_vocabulary.g.dart';
export 'workspace_feature_keys.dart';

part 'registry_ui.dart';

/// The version of the action/outcome contract below. Bumped when an
/// identifier is removed or changes meaning; adding one does not bump it.
const int actionContractVersion = 1;

/// What a step is.
enum StepKind {
  /// Something the person did on a registered surface.
  action('action'),

  /// Something the system reported: the result of a command.
  observation('observation'),

  /// A note the person wrote themselves, labelled as theirs.
  annotation('annotation'),

  /// A protected surface was visited. Only its category is kept.
  excluded('excluded'),

  /// Something happened the recorder cannot describe: an unregistered
  /// screen, an external app, a step from a newer contract.
  unrecorded('unrecorded');

  const StepKind(this.wire);
  final String wire;

  static StepKind? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// The kind of an action, which decides how the recorder treats repeats.
enum ActionKind {
  navigate('navigate'),
  select('select'),

  /// A value was committed in a field. Consecutive commits of the same
  /// field coalesce into one step, and the value itself is never kept.
  fieldCommit('field_commit'),
  open('open'),

  /// A command: it is recorded as an ATTEMPT before the command runs,
  /// and its outcome attaches to the attempt's local alias.
  submit('submit'),
  cancel('cancel'),
  back('back');

  const ActionKind(this.wire);
  final String wire;
}

/// The typed state of an observation.
enum ObservationState {
  /// The command was asked for; nothing is known about its result yet.
  attempted('attempted'),

  /// Accepted, and waiting on somebody else's decision.
  pending('pending'),
  confirmed('confirmed'),
  refused('refused'),

  /// The command ended without a result anybody can vouch for — a
  /// timeout, a lost connection, an exception nobody classified.
  outcomeUnknown('outcome_unknown');

  const ObservationState(this.wire);
  final String wire;

  static ObservationState? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// Surfaces whose CONTENT is never recorded. Visiting one leaves a single
/// "excluded step" marker carrying this category and nothing else.
enum ProtectedSurface {
  authentication('authentication'),
  payment('payment'),
  provider('provider'),
  secrets('secrets'),
  messenger('messenger'),
  identity('identity'),
  operator('operator');

  const ProtectedSurface(this.wire);
  final String wire;

  static ProtectedSurface? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// A screen or sheet the recorder knows by a stable identifier.
class RecorderSurface {
  const RecorderSurface(
    this.id, {
    this.version = 1,
    this.recorderControl = false,
  });

  final String id;
  final int version;

  /// The recorder's own controls. Nothing on them is ever recorded, so a
  /// recording cannot describe itself being made.
  final bool recorderControl;
}

/// One registered action.
class ActionSpec {
  const ActionSpec(
    this.id, {
    required this.surface,
    required this.kind,
    this.version = 1,
    this.payloadFields = const <String>{},
    this.targets = const <String>{},
    this.outcomes = const <String>{},
    this.softTargets = false,
  });

  final String id;
  final String surface;
  final ActionKind kind;

  /// #2142 — a target this build does not know is dropped on reading,
  /// not refused: the generic layer's names grow with the source.
  final bool softTargets;
  final int version;

  /// The safe payload fields (safe_payload.dart) this action may carry.
  final Set<String> payloadFields;

  /// The semantic targets (a field, a control) this action may name.
  final Set<String> targets;

  /// The outcomes that may answer this action. Non-empty only for a
  /// [ActionKind.submit].
  final Set<String> outcomes;

  bool get isCommand => kind == ActionKind.submit;
}

/// One registered outcome of a command.
class OutcomeSpec {
  const OutcomeSpec(
    this.id, {
    required this.state,
    this.version = 1,
    this.payloadFields = const <String>{},
  });

  final String id;
  final ObservationState state;
  final int version;
  final Set<String> payloadFields;
}

/// A prerequisite a recording may declare: what must be true before the
/// first step, stated without any binding to the session it came from.
class PrerequisiteSpec {
  const PrerequisiteSpec(this.id, {this.values = const <String>{}});

  final String id;

  /// The finite values the prerequisite may carry; empty means none.
  final Set<String> values;
}

/// The finite catalogue of surfaces, actions, outcomes and prerequisites.
class ActionRegistry {
  const ActionRegistry({
    required this.contractVersion,
    required this.surfaces,
    required this.actions,
    required this.outcomes,
    required this.prerequisites,
  });

  final int contractVersion;
  final List<RecorderSurface> surfaces;
  final List<ActionSpec> actions;
  final List<OutcomeSpec> outcomes;
  final List<PrerequisiteSpec> prerequisites;

  RecorderSurface? surface(Object? id) =>
      surfaces.where((s) => s.id == id).firstOrNull;

  ActionSpec? action(Object? id) =>
      actions.where((a) => a.id == id).firstOrNull;

  OutcomeSpec? outcome(Object? id) =>
      outcomes.where((o) => o.id == id).firstOrNull;

  PrerequisiteSpec? prerequisite(Object? id) =>
      prerequisites.where((p) => p.id == id).firstOrNull;

  /// Whether [actionId] is on the recorder's own controls.
  bool isRecorderControl(String actionId) =>
      surface(action(actionId)?.surface)?.recorderControl ?? false;

  /// Structural problems in the catalogue itself; empty when sound.
  /// Pinned by the registry test so a typo cannot ship.
  List<String> problems(Set<String> knownPayloadFields) {
    final errors = <String>[];
    void unique(Iterable<String> ids, String what) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) errors.add('duplicate $what $id');
        if (!RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(id)) {
          errors.add('$what id $id is not dotted snake_case');
        }
      }
    }

    unique(surfaces.map((s) => s.id), 'surface');
    unique(actions.map((a) => a.id), 'action');
    unique(outcomes.map((o) => o.id), 'outcome');
    for (final a in actions) {
      if (surface(a.surface) == null) {
        errors.add('${a.id}: unknown surface ${a.surface}');
      }
      if (a.isCommand != a.outcomes.isNotEmpty) {
        errors.add('${a.id}: a command needs outcomes, and only a command');
      }
      for (final o in a.outcomes) {
        if (outcome(o) == null) errors.add('${a.id}: unknown outcome $o');
      }
      for (final f in a.payloadFields) {
        if (!knownPayloadFields.contains(f)) {
          errors.add('${a.id}: unknown payload field $f');
        }
      }
    }
    for (final o in outcomes) {
      if (o.state == ObservationState.attempted) {
        errors.add('${o.id}: an outcome is never an attempt');
      }
      for (final f in o.payloadFields) {
        if (!knownPayloadFields.contains(f)) {
          errors.add('${o.id}: unknown payload field $f');
        }
      }
    }
    return errors;
  }
}

/// The surfaces of the first instrumented task: booking a place.
abstract final class RecorderSurfaces {
  static const reserve = 'reservations.reserve';
  static const bookingSheet = 'reservations.booking_sheet';
  static const reservationDetail = 'reservations.reservation_detail';

  /// #1881 A — my own reservation's sheet: check in, check out, cancel.
  static const myReservation = 'reservations.my_reservation';

  /// #1884 A — the workspace's feature switches.
  static const workspaceFeatures = 'workspace.features';
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

  // #2142 — a guarded command's real result.
  static const commandDone = 'command.done';
  static const commandPending = 'command.pending';
  static const commandRefused = 'command.refused';
  static const commandUnknown = 'command.unknown';

  // #1884 A — a setting's save.
  static const settingSaved = 'setting.saved';
  static const settingNotSaved = 'setting.not_saved';
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
      },
    ),
    ActionSpec(
      RecorderActions.declineOptIn,
      surface: RecorderSurfaces.workspaceFeatures,
      kind: ActionKind.cancel,
    ),
    ..._uiActions,
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
    ),
    ..._uiOutcomes,
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
      },
    ),
    PrerequisiteSpec('bookable_place'),
  ],
);
