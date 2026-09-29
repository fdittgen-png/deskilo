// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — a native client for one verified target. The repositories it
// hands out talk to THAT installation as THAT account; nothing here reads
// the app's current backend or workspace selection.
import '../../auth/domain/identity_binding.dart';
import '../../auth/domain/second_factor.dart';
import 'action_confirmation.dart';
import 'mcp_admin.dart';
import 'mcp_connection.dart';
import 'mcp_context.dart';

/// The native RPC adapters of one target, as one bundle.
class McpRepositories {
  const McpRepositories({
    required this.admin,
    required this.connections,
    required this.confirmations,
    required this.identity,
    required this.secondFactor,
  });

  final McpAdminRepository admin;
  final McpConnectionRepository connections;
  final ActionConfirmationRepository confirmations;
  final IdentityBindingRepository identity;

  /// This target's own second factor: a decision against it is checked
  /// against ITS session's assurance level, never the active backend's.
  final SecondFactorRepository secondFactor;
}

/// One client in the registry. Its session persistence and refresh belong
/// to its own target; disposing it touches no other target.
abstract interface class McpTargetClient {
  McpTargetKey get key;

  /// Runs [action] against this target's repositories.
  Future<T> run<T>(Future<T> Function(McpRepositories repositories) action);

  Future<void> dispose();
}
