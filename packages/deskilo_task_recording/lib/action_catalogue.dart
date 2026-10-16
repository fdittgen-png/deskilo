// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - the neutral action catalogue: what a recording may say happened.
//
// A recorded step names a registered SURFACE, a registered ACTION on it
// and, for a command, a registered OUTCOME. All are stable string
// identifiers with a version; the host application supplies the
// concrete catalogue (surfaces, actions, outcomes, payload vocabulary
// and its page validator) and this package never imports it. A
// recording that names something the supplied catalogue does not know
// is decoded as an unrecorded step and is not runnable.

import 'safe_payload.dart';

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
    required this.safeFields,
    required this.acceptsPage,
  });

  final int contractVersion;
  final List<RecorderSurface> surfaces;
  final List<ActionSpec> actions;
  final List<OutcomeSpec> outcomes;
  final List<PrerequisiteSpec> prerequisites;

  /// The only payload fields and values this catalogue lets through.
  final Map<String, SafeField> safeFields;

  /// Whether a recorded page reference is one the host can navigate to.
  final bool Function(String page) acceptsPage;

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
