// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - replay is never a permission.
//
// A recording or a guide names WHAT was done; whether it may be done now,
// by whom and where, is decided by the host at the moment of asking. The
// order is fixed:
//
//   step = a registered action at a known version, or a typed refusal
//   scope = the host's current qualified scope (an opaque token here)
//   decision = host.authorizeNow(step, scope)        - role, price, window
//   not allowed / confirmation missing -> refuse, or ask the host's own
//                                          confirmation
//   execute through the host's existing command, in THAT scope
//   record the actual outcome; an unknown outcome of a command is never
//   retried by the core
//
// Credentials, account or workspace identifiers never enter the core: the
// scope is a token the host derives and compares. A delayed answer is never
// attributed to another scope than the one it was asked in.

import 'action_catalogue.dart';
import 'task_recording.dart';

/// An opaque name for the verified account, workspace and installation an
/// action is asked in. Equal tokens are the same scope; nothing else is
/// known about it.
final class ReplayScope {
  const ReplayScope(this.token);

  final String token;

  @override
  bool operator ==(Object other) =>
      other is ReplayScope && other.token == token;

  @override
  int get hashCode => token.hashCode;
}

/// What is asked: a registered action, optionally on a named control, with
/// the safe (categorical) payload the recording kept for it.
class ReplayRequest {
  const ReplayRequest({
    required this.action,
    this.actionVersion,
    this.target,
    this.payload = const <String, String>{},
  });

  /// The request a recorded step stands for; null for a step that is not an
  /// action (an observation, a note, an excluded or unrecorded step).
  static ReplayRequest? fromStep(RecordedStep step) {
    final action = step.action;
    if (step.kind != StepKind.action || action == null) return null;
    return ReplayRequest(
      action: action,
      actionVersion: step.actionVersion,
      target: step.target,
      payload: step.payload.values,
    );
  }

  final String action;
  final int? actionVersion;
  final String? target;
  final Map<String, String> payload;
}

/// Why a request does not run.
enum ReplayRefusal {
  /// The catalogue does not know the action: never dynamically registered.
  unknownAction,

  /// The action was written by a newer contract than this catalogue's.
  unknownVersion,

  /// The host has no qualified scope (signed out, no workspace).
  noScope,

  /// The scope is not the one the request was started in.
  scopeChanged,

  /// The host refused it now: the role, the price rule, the feature.
  notAllowed,

  /// The same command's outcome was never learned; the person checks first.
  unknownOutcomePending,
}

enum ReplayVerdict { allowed, needsConfirmation, refused }

/// The host's answer to "may this be done now?".
class ReplayDecision {
  const ReplayDecision.allowed()
    : verdict = ReplayVerdict.allowed,
      reason = null;

  /// The host's own confirmation is required before the command may run.
  const ReplayDecision.needsConfirmation()
    : verdict = ReplayVerdict.needsConfirmation,
      reason = null;

  const ReplayDecision.refused([this.reason = ReplayRefusal.notAllowed])
    : verdict = ReplayVerdict.refused;

  final ReplayVerdict verdict;
  final ReplayRefusal? reason;
}

/// The host's authority over a replay: where we are and what is allowed now.
/// Asked every time; an earlier "yes" is never reused.
abstract interface class ReplayAuthorizer {
  /// The current qualified scope, or null when there is none.
  ReplayScope? currentScope();

  /// Whether [request] may be carried out in [scope] right now.
  ReplayDecision authorizeNow(ReplayRequest request, ReplayScope scope);
}

/// What a command answered.
class ReplayExecution {
  const ReplayExecution({required this.outcome, required this.state});

  /// A registered outcome id.
  final String outcome;
  final ObservationState state;
}

/// Carries a request out through the host's existing command - the one the
/// person's own tap would run, with its own validation and confirmation. A
/// throw means no answer is known.
abstract interface class ActionExecutor {
  Future<ReplayExecution> execute(
    ReplayRequest request,
    ReplayScope scope,
    ReplayDecision decision,
  );
}

/// An authorised request that has begun, bound to the scope it began in.
class ReplayTicket {
  ReplayTicket._(this.request, this.scope, this.decision);

  final ReplayRequest request;
  final ReplayScope scope;
  final ReplayDecision decision;
}

/// The result of asking to begin.
class ReplayStart {
  const ReplayStart._(this.ticket, this.verdict, this.reason);

  final ReplayTicket? ticket;
  final ReplayVerdict verdict;
  final ReplayRefusal? reason;

  bool get started => ticket != null;
}

enum ReplayStatus { executed, refused, needsConfirmation }

/// What a whole replay of one request came to.
class ReplayResult {
  const ReplayResult({
    required this.status,
    this.reason,
    this.execution,
    this.scope,
    this.scopeChangedDuring = false,
  });

  final ReplayStatus status;
  final ReplayRefusal? reason;

  /// The command's answer; null when none is known (refused, or it threw).
  final ReplayExecution? execution;

  /// The scope the command was ASKED in - the only one its answer belongs to.
  final ReplayScope? scope;

  /// The scope changed while the command ran: the answer is recorded for
  /// [scope], and the new scope inherits nothing from it.
  final bool scopeChangedDuring;
}

class ReplayCoordinator {
  ReplayCoordinator({
    required this.registry,
    required this.authorizer,
    this.executor,
  });

  final ActionRegistry registry;
  final ReplayAuthorizer authorizer;
  final ActionExecutor? executor;

  final Set<String> _unknownCommits = {};

  /// The typed reason a request cannot run at all, or null when the catalogue
  /// knows it.
  ReplayRefusal? nonRunnable(ReplayRequest request) {
    final spec = registry.action(request.action);
    if (spec == null) return ReplayRefusal.unknownAction;
    final version = request.actionVersion;
    if (version != null && version > spec.version) {
      return ReplayRefusal.unknownVersion;
    }
    return null;
  }

  /// Steps 1 to 4 of the order above, synchronously, so a caller that
  /// listens to the real command (the live guide) can decide before the
  /// command runs. [startedIn] is the scope the surrounding task began in.
  ReplayStart begin(
    ReplayRequest request, {
    required ReplayScope startedIn,
    bool confirmed = false,
  }) {
    ReplayStart refuse(ReplayRefusal reason) =>
        ReplayStart._(null, ReplayVerdict.refused, reason);

    final unknown = nonRunnable(request);
    if (unknown != null) return refuse(unknown);
    final scope = authorizer.currentScope();
    if (scope == null) return refuse(ReplayRefusal.noScope);
    if (scope != startedIn) return refuse(ReplayRefusal.scopeChanged);
    final command = registry.action(request.action)!.isCommand;
    if (command && _unknownCommits.contains(_commitKey(request, scope))) {
      return refuse(ReplayRefusal.unknownOutcomePending);
    }
    final decision = authorizer.authorizeNow(request, scope);
    switch (decision.verdict) {
      case ReplayVerdict.refused:
        return refuse(decision.reason ?? ReplayRefusal.notAllowed);
      case ReplayVerdict.needsConfirmation when !confirmed:
        return const ReplayStart._(null, ReplayVerdict.needsConfirmation, null);
      case ReplayVerdict.needsConfirmation:
      case ReplayVerdict.allowed:
        return ReplayStart._(
          ReplayTicket._(request, scope, decision),
          ReplayVerdict.allowed,
          null,
        );
    }
  }

  /// Whether the answer of [ticket] still belongs to the scope the host is
  /// in. When it does not, the answer is not applied anywhere.
  bool stillCurrent(ReplayTicket ticket) =>
      authorizer.currentScope() == ticket.scope;

  /// Notes what a command answered. An unknown outcome of a command is
  /// remembered: that command is not started again by the core.
  void record(ReplayTicket ticket, ObservationState state) {
    if (state == ObservationState.outcomeUnknown &&
        registry.action(ticket.request.action)?.isCommand == true) {
      _unknownCommits.add(_commitKey(ticket.request, ticket.scope));
    }
  }

  /// The person checked and found out what happened: the command may be
  /// asked for again.
  void clearUnknown(ReplayRequest request, ReplayScope scope) =>
      _unknownCommits.remove(_commitKey(request, scope));

  /// The whole order, for a host that executes: begin, execute through the
  /// existing command, record the actual outcome.
  Future<ReplayResult> replay(
    ReplayRequest request, {
    required ReplayScope startedIn,
    bool confirmed = false,
  }) async {
    final started = begin(request, startedIn: startedIn, confirmed: confirmed);
    final ticket = started.ticket;
    if (ticket == null) {
      return ReplayResult(
        status: started.verdict == ReplayVerdict.needsConfirmation
            ? ReplayStatus.needsConfirmation
            : ReplayStatus.refused,
        reason: started.reason,
      );
    }
    final run = executor;
    if (run == null) {
      return ReplayResult(status: ReplayStatus.executed, scope: ticket.scope);
    }
    ReplayExecution? execution;
    try {
      execution = await run.execute(request, ticket.scope, ticket.decision);
    } on Object {
      record(ticket, ObservationState.outcomeUnknown);
    }
    if (execution != null) record(ticket, execution.state);
    return ReplayResult(
      status: ReplayStatus.executed,
      execution: execution,
      scope: ticket.scope,
      scopeChangedDuring: !stillCurrent(ticket),
    );
  }

  String _commitKey(ReplayRequest request, ReplayScope scope) =>
      '${scope.token}|${request.action}|${request.target ?? ''}';
}
