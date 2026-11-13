// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may send an e-invoice, as the send function decides it: the owner,
// or an active member who holds issueInvoices — an administrator through
// the permission matrix, like anyone given it by a role (#2137).
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_permission.dart';

/// Whether [me], holding [permissions], may send an e-invoice.
bool maySendEInvoices(Member? me, Set<WorkspacePermission> permissions) =>
    me != null &&
    (me.actsAsOwner ||
        (me.status == MemberStatus.active &&
            permissions.contains(WorkspacePermission.issueInvoices)));
