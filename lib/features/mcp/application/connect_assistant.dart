// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1615 — connecting an assistant is three steps with two owners: this
// database records the chosen subset, Auth approves the authorization,
// this database makes the connection usable. The order is what keeps a
// failure honest: nothing is usable before Auth said yes, and an approval
// whose finalisation failed is retried, never reported as connected.
import '../domain/mcp_connection.dart';

enum ConnectOutcome {
  /// Usable; the browser goes back to the assistant.
  connected,

  /// Nothing was chosen: refused before anything was sent.
  nothingChosen,

  /// Auth approved, this database has not finalised yet: retry finalise.
  approvedNotFinalized,
}

class ConnectResult {
  const ConnectResult(this.outcome, {this.redirectTo});
  final ConnectOutcome outcome;
  final String? redirectTo;
}

class ConnectAssistant {
  const ConnectAssistant(
    this._repository,
    this._requestEligibility, {
    void Function(Object, StackTrace)? onFinalizeFailed,
  }) : _onFinalizeFailed = onFinalizeFailed;
  final void Function(Object, StackTrace)? _onFinalizeFailed;
  final McpConnectionRepository _repository;
  final Future<void> Function() _requestEligibility;

  /// Tells Auth no; answers where the browser goes back to.
  Future<String?> deny(String authorizationId) =>
      _repository.deny(authorizationId);

  /// Asks this database's administrators to approve MCP for the person.
  Future<void> requestEligibility() => _requestEligibility();

  Future<ConnectResult> connect(
    AuthorizationRequest request,
    Map<String, List<String>> scopes,
  ) async {
    final chosen = {
      for (final e in scopes.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };
    if (chosen.isEmpty) {
      return const ConnectResult(ConnectOutcome.nothingChosen);
    }
    await _repository.prepare(
      request.clientId,
      request.authorizationId,
      chosen,
    );
    final redirect = await _repository.approve(request.authorizationId);
    try {
      await _repository.finalize(request.authorizationId);
    } catch (error, stack) {
      // trace-exempt: traced by the provider's onFinalizeFailed (TraceLogger).
      // The approval stands and the caller says the connection is not
      // usable yet; the failure itself is recorded, not swallowed.
      _onFinalizeFailed?.call(error, stack);
      return ConnectResult(
        ConnectOutcome.approvedNotFinalized,
        redirectTo: redirect,
      );
    }
    return ConnectResult(ConnectOutcome.connected, redirectTo: redirect);
  }
}
