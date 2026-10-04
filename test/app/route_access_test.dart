// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may open which workspace screen: only someone holding one of its
// permissions; the screens that are not listed are every member's own.
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const treasurer = {
    WorkspacePermission.viewFinances,
    WorkspacePermission.issueInvoices,
    WorkspacePermission.manageBilling,
    WorkspacePermission.approveExpenses,
    WorkspacePermission.exportData,
  };
  const secretary = {
    WorkspacePermission.manageMembers,
    WorkspacePermission.manageDocuments,
    WorkspacePermission.viewPersonalData,
    WorkspacePermission.viewAnalytics,
  };

  test('a treasurer opens the money screens and nothing else', () {
    for (final path in ['/billing', '/invoicing/wizard', '/vat']) {
      expect(mayOpen(path, treasurer), isTrue, reason: path);
    }
    for (final path in [
      '/roles', '/members', '/features', '/workspace-settings', '/editor',
      '/validation', '/services', '/developer', '/settings/roles-of-this-space',
    ]) {
      expect(mayOpen(path, treasurer), isFalse, reason: path);
    }
  });

  test('a secretary opens the members screens and not the money ones', () {
    expect(mayOpen('/members', secretary), isTrue);
    expect(mayOpen('/invoicing/wizard', secretary), isFalse);
    expect(mayOpen('/billing', secretary), isFalse);
    expect(mayOpen('/roles', secretary), isFalse);
  });

  test('a member holds nothing by default: the everyday screens are theirs '
      'only through a role, and their own account always is', () {
    for (final path in ['/messages', '/reserve', '/calendar', '/money',
        '/directory', '/documents', '/members', '/editor/level/xyz']) {
      expect(mayOpen(path, const {}), isFalse, reason: path);
    }
    expect(mayOpen('/settings', const {}), isTrue);
    expect(mayOpen('/member/abc', const {}), isTrue);
    expect(mayOpen('/messages', {WorkspacePermission.useMessages}), isTrue);
    expect(mayOpen('/reserve', {WorkspacePermission.makeReservations}), isTrue);
    expect(landingFor(const {}), '/settings');
    expect(landingFor({WorkspacePermission.viewCalendar}), '/calendar');
  });

  test('every listed route is a registered workspace route', () {
    final registered = {
      for (final r in routeRules)
        if (r.kind == RouteClass.workspace) r.pattern,
    };
    for (final pattern in routePermissions.keys) {
      expect(registered, contains(pattern));
    }
  });
}
