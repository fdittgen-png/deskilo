// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/mcp/domain/action_confirmation.dart';

/// #1619 — in-memory confirmations for tests and Demo (which has none).
class FakeActionConfirmationRepository implements ActionConfirmationRepository {
  final confirmations = <String, ActionConfirmation>{};
  final answers = <({String id, bool accept})>[];

  @override
  Future<ActionConfirmation> get(String id) async =>
      confirmations[id] ?? ActionConfirmation(id: id, status: ConfirmationStatus.notFound);

  @override
  Future<ConfirmationStatus> respond(String id, {required bool accept}) async {
    answers.add((id: id, accept: accept));
    final c = confirmations[id];
    if (c == null) return ConfirmationStatus.notFound;
    if (!c.status.answerable) return c.status;
    final next = accept ? ConfirmationStatus.acknowledged : ConfirmationStatus.declined;
    confirmations[id] = ActionConfirmation(
      id: c.id,
      status: next,
      operation: c.operation,
      workspaceName: c.workspaceName,
      clientName: c.clientName,
      arguments: c.arguments,
      target: c.target,
      expiresAt: c.expiresAt,
    );
    return next;
  }
}
