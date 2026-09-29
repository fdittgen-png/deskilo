// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1627 — a database administrator decides an eligibility request. The
// server demands aal2 (require_database_reviewer); this reaches it with
// the person's real authenticator and never pretends. One decision id
// per request, kept for the screen's life, so a retry replays instead of
// deciding twice, and the request revision the reviewer saw is the one
// decided: if another administrator acted first, the answer is "changed".
//
// #1625 — the queue belongs to one installation, not to the selected
// workspace: a request is decided on the installation it was listed from,
// and so is its second factor. The check, the enrolment and the code all
// go through that installation's own registry client and session; the
// active backend's aal2 never vouches for a decision on another target.
// The check runs inside the same client call as the decision, so the
// session that was verified is the session that decides.
import '../../../core/ids/request_id.dart';
import '../../auth/domain/second_factor.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import 'mcp_commands.dart';

class EligibilityReview {
  EligibilityReview(this._commands, {this.instance});

  /// The installation whose maximum this screen administers; null while
  /// it is not verified, when nothing is saved.
  final McpInstanceRef? instance;
  final McpCommands _commands;
  final _decisionIds = <(McpInstanceRef, String, bool), String>{};

  McpScope _target(McpScope? scope) {
    final target = scope ?? instance;
    if (target == null) throw const McpTargetUnverified('');
    return target;
  }

  /// The second factor of [scope] (default: this screen's installation).
  Future<SecondFactorState> secondFactor([McpScope? scope]) =>
      _commands.read(_target(scope), (r) => r.secondFactor.state());

  Future<TotpEnrollment> enroll([McpScope? scope]) =>
      _commands.read(_target(scope), (r) => r.secondFactor.enrollTotp());

  Future<void> verify(String factorId, String code, [McpScope? scope]) =>
      _commands.read(
        _target(scope),
        (r) => r.secondFactor.verify(factorId, code),
      );

  /// #1809 — saves the installation maximum of optional fields; the
  /// server demands aal2 as for a decision, and so does this. Null when
  /// refused.
  Future<Set<String>?> setDisclosureMaximum(Set<String> fields) {
    final scope = _target(null);
    return _commands.execute(
      McpMutation<Object?>(
        scope: scope,
        operation: 'set_mcp_disclosure_maximum',
        payload: fields,
      ),
      (repositories, m) async {
        if (!(await repositories.secondFactor.state()).aal2) return null;
        return repositories.admin.setDisclosureMaximum(fields);
      },
    );
  }

  Future<EligibilityDecisionStatus> decide(
    EligibilityRequest request, {
    required bool approve,
  }) {
    final scope = request.scope;
    if (scope == null) throw const McpTargetUnverified('');
    final id = _decisionIds.putIfAbsent(
      (scope, request.requestId, approve),
      newRequestId,
    );
    return _commands.execute(
      McpMutation<Object?>(
        scope: scope,
        operation: 'decide_mcp_eligibility',
        payload: (request: request, approve: approve),
        mutationId: id,
      ),
      (repositories, m) async {
        if (!(await repositories.secondFactor.state()).aal2) {
          return EligibilityDecisionStatus.secondFactorRequired;
        }
        return repositories.admin.decide(
          request: request,
          decisionId: m.mutationId,
          approve: approve,
        );
      },
    );
  }
}
