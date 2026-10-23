// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (ADR 0047 §4–§6) — the setup status as the app reads it from
// `workspace_setup_status` (0539): every step with its state, and the four
// outcome milestones. The hub shows the one next action for the next
// milestone first, then what that milestone still needs, then what waits,
// what was set aside, what more the space could use, and what is done.

import '../../../core/data/json_reader.dart';

/// A time as the guide says it: a range, never a promise.
typedef SetupEstimate = ({int low, int high});

/// #2869 — a catalogue estimate as a range: from the estimate to twice
/// it. The rule for a step the instance has not observed often enough:
/// the server answers an observed range (`setup_step_timing_ranges`, the
/// median to the 80th percentile of the sessions that finished the step,
/// 9999) only from five sessions on, and the catalogue's one figure
/// (`setup_steps.dart`) is widened by this fixed rule below that.
SetupEstimate _estimateRange(int minutes) =>
    (low: minutes, high: minutes * 2);

/// A step's state, as the server words it.
enum SetupStepState {
  ready,
  needsConfiguration,
  blocked,
  needsOperator,
  notApplicable,
  deferred,
  unknown;

  static SetupStepState fromJson(Object? value) => switch (value) {
    'ready' => ready,
    'needs_configuration' => needsConfiguration,
    'blocked' => blocked,
    'needs_operator' => needsOperator,
    'not_applicable' => notApplicable,
    'deferred' => deferred,
    _ => unknown,
  };
}

/// One step and where it stands.
class SetupStepStatus {
  const SetupStepStatus({
    required this.step,
    required this.milestone,
    required this.required,
    required this.state,
    required this.route,
    this.blockedBy = const [],
    this.manual = false,
    this.estimateMinutes = 5,
    this.observed,
  });

  final String step;
  final String milestone;
  final bool required;
  final SetupStepState state;

  /// The in-app screen where it is done.
  final String route;

  /// The steps it waits for.
  final List<String> blockedBy;

  /// A step the server cannot verify: the owner marks it done.
  final bool manual;
  final int estimateMinutes;

  /// What the instance observed for this step, when it has seen enough
  /// sessions; null otherwise.
  final SetupEstimate? observed;

  /// The time as the guide says it: what was observed, else the
  /// catalogue's [estimateMinutes] widened.
  SetupEstimate get estimate => observed ?? _estimateRange(estimateMinutes);

  /// This step with [observed] set to what the instance knows, if anything.
  SetupStepStatus withObserved(SetupEstimate? range) => SetupStepStatus(
    step: step,
    milestone: milestone,
    required: required,
    state: state,
    route: route,
    blockedBy: blockedBy,
    manual: manual,
    estimateMinutes: estimateMinutes,
    observed: range,
  );

  bool get open =>
      state == SetupStepState.needsConfiguration ||
      state == SetupStepState.blocked ||
      state == SetupStepState.needsOperator;
}

/// A milestone and how far the space is from it.
class SetupMilestoneStatus {
  const SetupMilestoneStatus({
    required this.milestone,
    required this.applies,
    required this.required,
    required this.ready,
    required this.reached,
  });

  final String milestone;
  final bool applies;
  final int required;
  final int ready;
  final bool reached;
}

/// The whole answer.
class SetupStatus {
  const SetupStatus({this.steps = const [], this.milestones = const []});

  final List<SetupStepStatus> steps;
  final List<SetupMilestoneStatus> milestones;

  static SetupStatus fromJson(Object? json) {
    final r = JsonReader.orEmpty(json, context: 'workspace_setup_status');
    return SetupStatus(
      steps: [
        for (final raw in r.list('steps'))
          if (raw is Map) _step(JsonReader.of(raw, context: 'setup step')),
      ],
      milestones: [
        for (final raw in r.list('milestones'))
          if (raw is Map)
            _milestone(JsonReader.of(raw, context: 'setup milestone')),
      ],
    );
  }

  static SetupStepStatus _step(JsonReader s) {
    final route = s.stringOr('route');
    return SetupStepStatus(
      step: s.stringOr('step'),
      milestone: s.stringOr('milestone'),
      required: s.boolOr('required', fallback: false),
      state: SetupStepState.fromJson(s.stringOrNull('state')),
      // Only an in-app route is followed.
      route: route.startsWith('/') ? route : '/workspace-settings',
      blockedBy: s.strings('blocked_by'),
      manual: s.boolOr('manual', fallback: false),
      estimateMinutes: s.intOrNull('estimate_minutes') ?? 5,
    );
  }

  static SetupMilestoneStatus _milestone(JsonReader m) => SetupMilestoneStatus(
    milestone: m.stringOr('milestone'),
    applies: m.boolOr('applies', fallback: false),
    required: m.intOrNull('required') ?? 0,
    ready: m.intOrNull('ready') ?? 0,
    reached: m.boolOr('reached', fallback: false),
  );

  /// The first milestone this space has chosen and not reached; null when
  /// every one it chose is reached.
  SetupMilestoneStatus? get nextMilestone {
    for (final m in milestones) {
      if (m.applies && !m.reached) return m;
    }
    return null;
  }

  int _rank(String milestone) =>
      milestones.indexWhere((m) => m.milestone == milestone);

  bool _forNext(SetupStepStatus s) {
    final next = nextMilestone;
    return next != null && _rank(s.milestone) <= _rank(next.milestone);
  }

  /// What the next milestone still needs, in guide order.
  List<SetupStepStatus> get toDo => [
    for (final s in steps)
      if (s.required && _forNext(s) && s.open) s,
  ];

  /// The one next action: the first of [toDo] the owner can act on now,
  /// else the first of a later milestone, else the first optional step.
  SetupStepStatus? get nextStep {
    for (final s in toDo) {
      if (s.state == SetupStepState.needsConfiguration) return s;
    }
    return [...later, ...optional].firstOrNull;
  }

  /// Steps that wait for another step or for the operator, outside [toDo].
  List<SetupStepStatus> get waiting => [
    for (final s in steps)
      if (!toDo.contains(s) &&
          (s.state == SetupStepState.blocked ||
              s.state == SetupStepState.needsOperator))
        s,
  ];

  List<SetupStepStatus> get deferred => [
    for (final s in steps)
      if (s.state == SetupStepState.deferred) s,
  ];

  /// What a later milestone needs, still open.
  List<SetupStepStatus> get later => [
    for (final s in steps)
      if (s.required &&
          !toDo.contains(s) &&
          s.state == SetupStepState.needsConfiguration)
        s,
  ];

  /// What more the space could use: open steps no milestone waits for.
  List<SetupStepStatus> get optional => [
    for (final s in steps)
      if (!s.required && s.state == SetupStepState.needsConfiguration) s,
  ];

  /// #2869 — what the next milestone still needs, as a range: its open
  /// steps' ranges summed end to end, each observed or from the catalogue.
  SetupEstimate get toNextMilestone => (
    low: toDo.fold(0, (sum, s) => sum + s.estimate.low),
    high: toDo.fold(0, (sum, s) => sum + s.estimate.high),
  );

  /// This status with every step's observed range taken from [ranges]
  /// (by step id); a step the instance has not observed keeps none.
  SetupStatus withObserved(Map<String, SetupEstimate> ranges) => SetupStatus(
    steps: [for (final s in steps) s.withObserved(ranges[s.step])],
    milestones: milestones,
  );

  /// #2869 — steps outside the levels the owner chose. The server marks a
  /// step `not_applicable` only when its feature is off (0539), so these
  /// are not in the plan: no milestone counts them and no group above
  /// lists them. The guide offers them, folded, under "Add more to your
  /// space", and every counter of the plan stays what it was.
  List<SetupStepStatus> get addable => [
    for (final s in steps)
      if (s.state == SetupStepState.notApplicable) s,
  ];

  List<SetupStepStatus> get done => [
    for (final s in steps)
      if (s.state == SetupStepState.ready) s,
  ];
}
