// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1619/#1449 — answering an assistant's confirmation request. The
// decision is the server's (mcp_confirm_action re-checks eligibility,
// permission and the target revision); the screen asks this command, so
// it resolves no repository itself.
import '../domain/action_confirmation.dart';

class ConfirmationAnswers {
  const ConfirmationAnswers(this._repository);
  final ActionConfirmationRepository _repository;

  Future<ConfirmationStatus> answer(String id, {required bool accept}) =>
      _repository.respond(id, accept: accept);
}
