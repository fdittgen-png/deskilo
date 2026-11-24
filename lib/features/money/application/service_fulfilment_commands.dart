// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the one door for what an issuer does to an engagement. The server
// decides everything (who may, the revision, which step); the answer is a closed
// outcome the screen words, never an exception it has to guess at. A write is
// never retried here: a lost answer is [CommandUnreached], and the screen
// retries with the SAME request identity, which the server answers once.
import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../domain/service_fulfilment.dart';

class ServiceFulfilmentCommands {
  const ServiceFulfilmentCommands(this._repository);

  final ServiceFulfilmentRepository _repository;

  /// Opens the engagement of a quote or invoice line, or finds it.
  Future<CommandOutcome<FulfilmentOpened>> openFromLine(
    String workspaceId, {
    required String requestId,
    required String kind,
    required String id,
    required String lineId,
  }) => _run(
    () => _repository.openFromLine(
      workspaceId,
      requestId: requestId,
      kind: kind,
      id: id,
      lineId: lineId,
    ),
  );

  /// Commits a direct engagement.
  Future<CommandOutcome<FulfilmentOpened>> openDirect(
    String workspaceId, {
    required String requestId,
    required DirectEngagementInput input,
  }) => _run(
    () =>
        _repository.openDirect(workspaceId, requestId: requestId, input: input),
  );

  /// One step at the revision [from] was read at. A cancellation needs a reason
  /// ([stepNeedsReason]); the server refuses one without.
  Future<CommandOutcome<ServiceFulfilment>> step(
    String workspaceId,
    ServiceFulfilment from, {
    required FulfilmentState to,
    required String requestId,
    String reason = '',
  }) => _run(
    () => _repository.transition(
      workspaceId,
      from.id,
      expectedRevision: from.revision,
      to: to,
      requestId: requestId,
      reason: reason.trim(),
    ),
  );

  /// Records that [lineId] of [invoiceId] billed a direct engagement.
  Future<CommandOutcome<ServiceFulfilment>> linkInvoice(
    String workspaceId,
    String fulfilmentId, {
    required String invoiceId,
    required String lineId,
  }) => _run(
    () => _repository.linkInvoice(
      workspaceId,
      fulfilmentId,
      invoiceId: invoiceId,
      lineId: lineId,
    ),
  );

  /// Runs [body]: done, refused with its [FulfilmentRefusal] as the cause,
  /// or not reached; logged once.
  Future<CommandOutcome<T>> _run<T>(Future<T> Function() body) =>
      runCommand(body, what: 'a service fulfilment command was not answered');

}
