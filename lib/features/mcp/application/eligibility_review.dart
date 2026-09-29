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
// workspace: a request is decided on the installation it was listed from.
import '../../../core/ids/request_id.dart';
import '../../auth/domain/second_factor.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import 'mcp_commands.dart';

class EligibilityReview {
  EligibilityReview(this._commands, this._factors);
  final McpCommands _commands;
  final SecondFactorRepository _factors;
  final _decisionIds = <(McpInstanceRef, String, bool), String>{};

  Future<SecondFactorState> secondFactor() => _factors.state();
  Future<TotpEnrollment> enroll() => _factors.enrollTotp();
  Future<void> verify(String factorId, String code) =>
      _factors.verify(factorId, code);

  Future<EligibilityDecisionStatus> decide(
    EligibilityRequest request, {
    required bool approve,
  }) async {
    if (!(await _factors.state()).aal2) {
      return EligibilityDecisionStatus.refused;
    }
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
      (repositories, m) => repositories.admin.decide(
        request: request,
        decisionId: m.mutationId,
        approve: approve,
      ),
    );
  }
}
