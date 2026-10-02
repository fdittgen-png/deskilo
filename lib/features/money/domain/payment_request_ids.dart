// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 B — one request id per payment the member is trying to make. A
// retry of the same payment (same workspace, member, provider, period and
// amount) sends the SAME id, so the server answers with the intent it
// already opened and the provider with the order it already made — a lost
// answer never becomes a second charge. The id is dropped only when the
// server has given a definitive answer that needs a NEW request (the
// intent failed, went stale, or the body was refused); an unknown outcome
// keeps it.
import '../../../core/ids/request_id.dart';
import 'payment_provider.dart';

class PaymentRequestIds {
  PaymentRequestIds([String Function()? mint]) : _mint = mint ?? newRequestId;

  final String Function() _mint;
  final _ids = <String, String>{};

  static String _key(
    String workspaceId,
    String memberId,
    PaymentProvider provider,
    String period,
    int amountCents,
  ) => '$workspaceId|$memberId|${provider.wireName}|$period|$amountCents';

  /// The id for this payment: the one already in use, or a fresh one.
  String idFor(
    String workspaceId,
    String memberId,
    PaymentProvider provider,
    String period,
    int amountCents,
  ) => _ids.putIfAbsent(
    _key(workspaceId, memberId, provider, period, amountCents),
    _mint,
  );

  /// After a failed call: forget the id when [error] is definitive.
  void afterError(
    String workspaceId,
    String memberId,
    PaymentProvider provider,
    String period,
    int amountCents,
    Object error,
  ) {
    if (isDefinitive(error)) {
      _ids.remove(_key(workspaceId, memberId, provider, period, amountCents));
    }
  }

  /// Runs [call] with this payment's id, forgetting the id when the call
  /// fails definitively; the error is rethrown with its stack trace.
  Future<T> run<T>(
    String workspaceId,
    String memberId,
    PaymentProvider provider,
    String period,
    int amountCents,
    Future<T> Function(String requestId) call,
  ) async {
    try {
      return await call(
        idFor(workspaceId, memberId, provider, period, amountCents),
      );
    } catch (e, st) {
      // trace-exempt: rethrown to the caller, which traces it.
      afterError(workspaceId, memberId, provider, period, amountCents, e);
      Error.throwWithStackTrace(e, st);
    }
  }

  /// A 4xx or a provider refusal (502) is definitive; a 5xx timeout or
  /// unknown outcome (503), a network error or anything else is not.
  static bool isDefinitive(Object error) =>
      error is PaymentGatewayException &&
      ((error.status >= 400 && error.status < 500) || error.status == 502);
}
