// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/mcp/domain/action_confirmation.dart';

/// #1619 — in-memory confirmations for tests and Demo (which has none).
class FakeActionConfirmationRepository implements ActionConfirmationRepository {
  final confirmations = <String, ActionConfirmation>{};
  final answers = <({String id, bool accept})>[];

  /// #3962 — what the Demo does once a request is answered (it decides the
  /// event the assistant asked about); null: nothing.
  Future<void> Function(ActionConfirmation request, {required bool accept})?
  onAnswered;

  @override
  Future<ActionConfirmation> get(String id) async =>
      confirmations[id] ?? ActionConfirmation(id: id, status: ConfirmationStatus.notFound);

  @override
  Future<List<ActionConfirmation>> mine({
    required DateTime answeredSince,
  }) async => [
    for (final c in confirmations.values)
      if (c.status.answerable ||
          !(c.askedAt?.isBefore(answeredSince) ?? false))
        c,
  ]..sort(
    (a, b) => (b.askedAt ?? answeredSince).compareTo(
      a.askedAt ?? answeredSince,
    ),
  );

  @override
  Future<ConfirmationStatus> respond(String id, {required bool accept}) async {
    answers.add((id: id, accept: accept));
    final c = confirmations[id];
    if (c == null) return ConfirmationStatus.notFound;
    if (!c.status.answerable) return c.status;
    final next = accept ? ConfirmationStatus.acknowledged : ConfirmationStatus.declined;
    await onAnswered?.call(c, accept: accept);
    confirmations[id] = c.withStatus(next);
    return next;
  }
}
