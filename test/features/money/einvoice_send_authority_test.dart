// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may send an e-invoice: the owner, or an active member who holds
// issueInvoices; an administrator without it is not offered Send.
import 'package:deskilo/features/money/application/einvoice_send_authority.dart';
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
    expect(maySendEInvoices(_m(admin: true), const {}), isFalse);
    expect(maySendEInvoices(_m(admin: true), issue), isTrue);
  });

  test('a member given the right by a role sends; one without does not', () {
    expect(maySendEInvoices(_m(), issue), isTrue);
    expect(maySendEInvoices(_m(), const {}), isFalse);
  });

  test('the owner sends; nobody inactive or absent does', () {
    expect(maySendEInvoices(_m(owner: true), const {}), isTrue);
    expect(maySendEInvoices(_m(status: MemberStatus.paused), issue), isFalse);
    expect(maySendEInvoices(null, issue), isFalse);
  });
}
