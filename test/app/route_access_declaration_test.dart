// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — a route's access declaration (RouteAccess) answers from a plain
// record, with no router and no providers: features, permission, role
// bypass and the extra condition, and where a refusal goes.
import 'package:deskilo/app/route_access.dart';
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

  test('a permission opens it, nothing else does, the default is /messages', () {
    const access = RouteAccess(permission: WorkspacePermission.manageBilling);
    expect(access.redirectFor(_Person()), '/messages');
    expect(access.redirectFor(_Person(actsAsOwner: true)), '/messages');
    expect(
      access.redirectFor(
        _Person(permissions: {WorkspacePermission.manageBilling}),
      ),
      isNull,
    );
  });

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
}
