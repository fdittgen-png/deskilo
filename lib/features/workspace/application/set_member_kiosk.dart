// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Which account runs the tablet by the door. A kiosk account locks to the
// plan and acts only through members' badges; the server lets only an
// owner set it. The setup guide's kiosk step names one through this class.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/member.dart';
import '../domain/membership_repository.dart';
import '../providers/workspace_providers.dart';

part 'set_member_kiosk.g.dart';

class SetMemberKiosk {
  const SetMemberKiosk(this._members);
  final MembershipRepository _members;

  /// Makes [member] a kiosk account. False, nothing sent, when it already
  /// is one, or is not an active member. A refusal propagates.
  Future<bool> make(Member member) async {
    if (member.isKiosk || member.status != MemberStatus.active) return false;
    await _members.setMemberKiosk(member.id, isKiosk: true);
    return true;
  }
}

/// The kiosk account's write.
@riverpod
SetMemberKiosk setMemberKiosk(Ref ref) =>
    SetMemberKiosk(ref.watch(workspaceRepositoryProvider));
