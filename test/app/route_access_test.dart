// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may open which workspace screen: only someone holding one of its
// permissions, the screens that are not listed being every member's own; and
// #2493, a route's access declaration (RouteAccess) answering from a plain
// record with no router and no providers: features, permission, role bypass,
// the extra condition and where a refusal goes (formerly
// route_access_declaration_test.dart, now the group of that name).
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

class _Person implements AccessContext {
  _Person({
    this.features = const {},
    this.permissions = const {},
    this.actsAsOwner = false,
    this.canAdminister = false,
    this.hasPairedTwin = false,
  });

  final Set<WorkspaceFeature> features;
  @override
  final Set<WorkspacePermission> permissions;
  @override
  final bool actsAsOwner;
  @override
  final bool canAdminister;
  @override
  final bool hasPairedTwin;

  @override
  Set<WorkspaceFeature> get enabledFeatures => features;
  @override
  bool featureEnabled(WorkspaceFeature feature) => features.contains(feature);
  @override
  bool get isAdmin => canAdminister;
}

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
      '/roles',
      '/members',
      '/features',
      '/workspace-settings',
      '/editor',
      '/validation',
      '/services',
      '/developer',
      '/settings/roles-of-this-space',
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
    for (final path in [
      '/messages',
      '/reserve',
      '/calendar',
      '/money',
      '/directory',
      '/documents',
      '/members',
      '/editor/level/xyz',
    ]) {
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

  group('route_access_declaration_test', () {
    test('no declaration: anyone passes', () {
      expect(const RouteAccess().redirectFor(_Person()), isNull);
    });

    test('a feature that is off sends the person to the fallback', () {
      const access = RouteAccess(
        features: [WorkspaceFeature.invoicing],
        to: '/money',
      );
      expect(access.redirectFor(_Person()), '/money');
      expect(
        access.redirectFor(_Person(features: {WorkspaceFeature.invoicing})),
        isNull,
      );
    });

    test(
      'a permission opens it, nothing else does, the default is /messages',
      () {
        const access = RouteAccess(
          permission: WorkspacePermission.manageBilling,
        );
        expect(access.redirectFor(_Person()), '/messages');
        expect(access.redirectFor(_Person(actsAsOwner: true)), '/messages');
        expect(
          access.redirectFor(
            _Person(permissions: {WorkspacePermission.manageBilling}),
          ),
          isNull,
        );
      },
    );

    test('a role bypass opens it without the permission', () {
      const owner = RouteAccess(
        permission: WorkspacePermission.manageSites,
        bypass: RoleBypass.owner,
      );
      expect(owner.redirectFor(_Person(actsAsOwner: true)), isNull);
      expect(owner.redirectFor(_Person(canAdminister: true)), '/messages');
      const admin = RouteAccess(bypass: RoleBypass.administrator);
      expect(admin.redirectFor(_Person(canAdminister: true)), isNull);
      expect(admin.redirectFor(_Person()), '/messages');
    });

    test('feature, person and the extra condition must all hold', () {
      final access = RouteAccess(
        features: const [WorkspaceFeature.deployments],
        permission: WorkspacePermission.deployToDev,
        when: (c) => c.hasPairedTwin,
        to: '/settings',
      );
      final allowed = _Person(
        features: {WorkspaceFeature.deployments},
        permissions: {WorkspacePermission.deployToDev},
        hasPairedTwin: true,
      );
      expect(access.redirectFor(allowed), isNull);
      expect(
        access.redirectFor(
          _Person(
            features: {WorkspaceFeature.deployments},
            permissions: {WorkspacePermission.deployToDev},
          ),
        ),
        '/settings',
      );
    });
  });
}
