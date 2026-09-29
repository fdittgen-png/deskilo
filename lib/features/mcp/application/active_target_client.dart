// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — the active backend as a registry client. It borrows the app's
// own repositories and session (the main app still owns sign-in, refresh
// and the backend switch) and refuses, typed, once that session is no
// longer the account it was captured for: a request captured on A never
// runs as whoever is signed in after a switch.
import '../domain/mcp_client.dart';
import '../domain/mcp_context.dart';

class ActiveMcpTargetClient implements McpTargetClient {
  ActiveMcpTargetClient(
    this.key,
    this._repositories, {
    required this._currentAccount,
  });

  @override
  final McpTargetKey key;

  /// The app's current repositories, read per call (they are the main
  /// app's to rebuild); the account check is what binds them to [key].
  final McpRepositories Function() _repositories;
  final String? Function() _currentAccount;
  bool _disposed = false;

  void _check() {
    if (_disposed || _currentAccount() != key.account) {
      throw const McpTargetChanged();
    }
  }

  @override
  Future<T> run<T>(
    Future<T> Function(McpRepositories repositories) action,
  ) async {
    _check();
    final answer = await action(_repositories());
    _check();
    return answer;
  }

  /// The borrowed session is the main app's: disposing this client stops
  /// its use here and signs nobody out.
  @override
  Future<void> dispose() async => _disposed = true;
}
