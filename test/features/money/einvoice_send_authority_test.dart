// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may send an e-invoice: the owner, or an active member who holds
// issueInvoices; an administrator without it is not offered Send.
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m({bool admin = false, bool owner = false, MemberStatus? status}) =>
    Member(
      id: 'm',
      workspaceId: 'ws',
      userId: 'u',
      isAdmin: admin,
      isOwner: owner,
      status: status ?? MemberStatus.active,
    );

void main() {
  const issue = {WorkspacePermission.issueInvoices};

  test('an administrator sends only with the right to issue invoices', () {
    expect(_m(admin: true).maySendEInvoices(const {}), isFalse);
    expect(_m(admin: true).maySendEInvoices(issue), isTrue);
  });

  test('a member given the right by a role sends; one without does not', () {
    expect(_m().maySendEInvoices(issue), isTrue);
    expect(_m().maySendEInvoices(const {}), isFalse);
  });

  test('the owner sends; nobody inactive does', () {
    expect(_m(owner: true).maySendEInvoices(const {}), isTrue);
    expect(_m(status: MemberStatus.paused).maySendEInvoices(issue), isFalse);
  });
}
