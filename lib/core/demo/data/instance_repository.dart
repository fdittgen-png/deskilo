// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/instance_responsibles.dart';

/// #1829 — in-memory instance owner and delegates for tests and Demo
/// (where nobody is named: the visitor is not a Deskilo account).
class FakeInstanceRepository implements InstanceRepository {
  FakeInstanceRepository({InstanceResponsibles? state})
    : current = state ?? InstanceResponsibles.unavailable;

  InstanceResponsibles current;
  final delegated = <String>[];
  final withdrawn = <String>[];
  var claims = 0;
  DelegationOutcome nextDelegation = DelegationOutcome.delegated;

  @override
  Future<InstanceResponsibles> responsibles() async => current;

  @override
  Future<DelegationOutcome> delegate(String email) async {
    delegated.add(email);
    return nextDelegation;
  }

  @override
  Future<bool> withdraw(String userId) async {
    withdrawn.add(userId);
    return true;
  }

  @override
  Future<bool> claim() async {
    claims++;
    return true;
  }
}
