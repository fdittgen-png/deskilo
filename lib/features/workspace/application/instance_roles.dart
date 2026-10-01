// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1829 — what the owner asks of the instance's roles. The sheet says
// what was asked for; this decides what it comes to: an address is
// trimmed and an empty one is never sent. Who may delegate, and what a
// delegate may then do, is the server's decision (0314), never this one.
import '../domain/instance_responsibles.dart';

class InstanceRoles {
  const InstanceRoles(this._repository);

  final InstanceRepository _repository;

  /// Delegate the role to the account with this e-mail address.
  Future<DelegationOutcome> delegate(String email) {
    final address = email.trim();
    if (address.isEmpty) return Future.value(DelegationOutcome.noAccount);
    return _repository.delegate(address);
  }

  /// Whether the delegation of [userId] was actually withdrawn.
  Future<bool> withdraw(String userId) => _repository.withdraw(userId);

  /// Whether the caller became the owner of a new instance.
  Future<bool> claim() => _repository.claim();
}
