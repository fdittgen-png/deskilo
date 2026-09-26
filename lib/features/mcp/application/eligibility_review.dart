// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1627 — a database administrator decides an eligibility request. The
// server demands aal2 (require_database_reviewer); this reaches it with
// the person's real authenticator and never pretends. One decision id
// per request, kept for the screen's life, so a retry replays instead of
// deciding twice, and the request revision the reviewer saw is the one
// decided: if another administrator acted first, the answer is "changed".
import '../../../core/ids/request_id.dart';
import '../../auth/domain/second_factor.dart';
import '../domain/mcp_admin.dart';

class EligibilityReview {
  EligibilityReview(this._repository, this._factors);
  final McpAdminRepository _repository;
  final SecondFactorRepository _factors;
  final _decisionIds = <String, String>{};

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
    final id = _decisionIds.putIfAbsent(
      '${request.requestId}:$approve',
      newRequestId,
    );
    return _repository.decide(
      request: request,
      decisionId: id,
      approve: approve,
    );
  }
}
