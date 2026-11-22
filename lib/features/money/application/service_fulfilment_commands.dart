// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the one door for what an issuer does to an engagement. The server
// decides everything (who may, the revision, which step); the answer is a closed
// outcome the screen words, never an exception it has to guess at. A write is
// never retried here: a lost answer is [FulfilmentUnreached], and the screen
// retries with the SAME request identity, which the server answers once.
import '../../../core/trace/trace_logger.dart';
import '../domain/service_fulfilment.dart';

sealed class FulfilmentOutcome<T> {
  const FulfilmentOutcome();
}

/// The server did it, or had already done it; [value] is its answer.
final class FulfilmentDone<T> extends FulfilmentOutcome<T> {
  const FulfilmentDone(this.value);
  final T value;
}

/// The server refused: nothing was written.
final class FulfilmentRefused<T> extends FulfilmentOutcome<T> {
  const FulfilmentRefused(this.refusal);
  final FulfilmentRefusal refusal;
}

/// The answer never came (a lost connection, an older host): whether it was done
/// is not known, so nothing is claimed.
final class FulfilmentUnreached<T> extends FulfilmentOutcome<T> {
  const FulfilmentUnreached();
}

class ServiceFulfilmentCommands {
  const ServiceFulfilmentCommands(this._repository);

  final ServiceFulfilmentRepository _repository;

  /// Opens the engagement of a quote or invoice line, or finds it.
  Future<FulfilmentOutcome<FulfilmentOpened>> openFromLine(
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
  Future<FulfilmentOutcome<FulfilmentOpened>> openDirect(
    String workspaceId, {
    required String requestId,
    required DirectEngagementInput input,
  }) => _run(
    () =>
        _repository.openDirect(workspaceId, requestId: requestId, input: input),
  );

  /// One step at the revision [from] was read at. A cancellation needs a reason
  /// ([stepNeedsReason]); the server refuses one without.
  Future<FulfilmentOutcome<ServiceFulfilment>> step(
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
  Future<FulfilmentOutcome<ServiceFulfilment>> linkInvoice(
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

  Future<FulfilmentOutcome<T>> _run<T>(Future<T> Function() body) async {
    try {
      return FulfilmentDone(await body());
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'a service fulfilment command was not answered',
        error: e,
        stackTrace: st,
      );
      return e is FulfilmentRefusal
          ? FulfilmentRefused<T>(e)
          : FulfilmentUnreached<T>();
    }
  }
}
