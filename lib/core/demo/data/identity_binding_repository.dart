// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/auth/domain/identity_binding.dart';

/// #1647 — in-memory binding for tests and Demo. Starts [initial];
/// finalize binds unless [finalizeAnswer] scripts another outcome.
class FakeIdentityBindingRepository implements IdentityBindingRepository {
  FakeIdentityBindingRepository({
    IdentityBindingStatus initial = const IdentityBindingStatus(
      state: IdentityBindingState.unavailable,
      reason: 'no_authority',
    ),
    this.finalizeAnswer,
  }) : _current = initial;

  IdentityBindingStatus _current;
  IdentityBindingStatus? finalizeAnswer;
  int finalizeCalls = 0;

  @override
  Future<IdentityBindingStatus> status() async => _current;

  @override
  Future<IdentityBindingStatus> finalize() async {
    finalizeCalls++;
    return _current = finalizeAnswer ?? _current;
  }

  @override
  Future<IdentityBindingStatus> revoke() async => _current =
      const IdentityBindingStatus(state: IdentityBindingState.unlinked);

  DatabaseCapabilities capabilities = DatabaseCapabilities.unavailable;

  @override
  Future<DatabaseCapabilities> databaseCapabilities() async => capabilities;

  /// A request never approves itself: it answers `requested`.
  @override
  Future<DatabaseCapabilities> requestMcpEligibility() async =>
      capabilities = const DatabaseCapabilities(eligibility: McpEligibility.requested);

  @override
  Future<DatabaseCapabilities> withdrawMcpEligibility() async =>
      capabilities = const DatabaseCapabilities(eligibility: McpEligibility.notRequested);
}
