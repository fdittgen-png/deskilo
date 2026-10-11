// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/vies_check.dart';
import '../domain/vies_repository.dart';

/// #2354 — "check this member's VAT number against VIES": the decision
/// behind the member page's Check now. The server decides who may ask
/// and records the answer; an outage is an answer too.
class CheckVies {
  const CheckVies(this._repository);

  final ViesRepository _repository;

  /// Throws whatever the repository throws; the caller reports it.
  Future<ViesCheck> call(String workspaceId, String memberId) =>
      _repository.checkVies(workspaceId, memberId);
}
