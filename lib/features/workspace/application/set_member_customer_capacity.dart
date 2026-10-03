// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1916 — stating whether a member acts as a business or a consumer
// customer. The capacity decides which payment clauses the member's
// invoices print; it is stated, never inferred.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/member.dart';
import '../domain/workspace_repository.dart';
import '../providers/workspace_providers.dart';

part 'set_member_customer_capacity.g.dart';

/// The capacities a member can be given; '' is "not stated".
const List<String> customerCapacityWires = ['', 'business', 'consumer'];

class MemberCustomerCapacities {
  const MemberCustomerCapacities(this._workspaces);
  final WorkspaceRepository _workspaces;

  /// Sets [member]'s capacity to [wire] ('' clears it). Returns false
  /// when there is nothing to write; a server refusal propagates.
  Future<bool> set(Member member, String wire) async {
    if (!customerCapacityWires.contains(wire)) {
      throw ArgumentError.value(wire, 'wire', 'unknown customer capacity');
    }
    if (wire == (member.customerCapacity ?? '')) return false;
    await _workspaces.setMemberCustomerCapacity(
      member.id,
      wire.isEmpty ? null : wire,
    );
    return true;
  }
}

/// #1916 — the command that states a member's customer capacity.
@riverpod
MemberCustomerCapacities memberCustomerCapacities(Ref ref) =>
    MemberCustomerCapacities(ref.watch(workspaceRepositoryProvider));
