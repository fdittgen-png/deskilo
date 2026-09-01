// SPDX-License-Identifier: 0BSD
//
// #513 — CENTRALIZED role management: one permission catalog, one
// matrix per workspace. The owner always holds everything (locked
// row); whoever holds manageRoles edits the other rows; everyone else
// reads the matrix — their own role highlighted — but cannot change
// a thing.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pumpRoles(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  workspace ??= FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go('/roles');
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  group('permission model (#513)', () {
    test('defaults match today: owner all, co-owner all, admin the '
        'admin set, member none', () {
      expect(defaultPermissionsFor(PermissionRole.owner),
          WorkspacePermission.values.toSet());
      expect(defaultPermissionsFor(PermissionRole.coOwner),
          WorkspacePermission.values.toSet());
      expect(
        defaultPermissionsFor(PermissionRole.admin),
        {
          WorkspacePermission.manageMembers,
          WorkspacePermission.manageDocuments,
          WorkspacePermission.manageServices,
          WorkspacePermission.approveExpenses,
          WorkspacePermission.viewFinances,
          WorkspacePermission.viewNegotiations,
          WorkspacePermission.manageNegotiations,
        },
      );
      expect(defaultPermissionsFor(PermissionRole.member), isEmpty);
    });

    test('a stored matrix row REPLACES the defaults; the legacy '
        'adminInvoicing flag keeps granting invoicing to admins', () {
      final workspace = FakeWorkspaceRepository.withWorkspace()
          .workspaces
          .single
          .copyWith(rolePermissions: {
        'admin': ['issueInvoices'],
      });
      final granted =
          permissionsForRole(PermissionRole.admin, workspace);
      expect(granted, {WorkspacePermission.issueInvoices});

      final flagged = workspace.copyWith(
        rolePermissions: const {},
        featureFlags: const {'adminInvoicing': true},
      );
      expect(
        permissionsForRole(PermissionRole.admin, flagged),
        contains(WorkspacePermission.issueInvoices),
      );
    });
  });

  testWidgets(
      'the OWNER edits the matrix: owner row locked all-on, toggling an '
      'admin permission persists through the repository (#513)',
      (tester) async {
    final workspace = await _pumpRoles(tester);

    // Owner row: everything checked and locked.
    final ownerTile = find.byKey(
        const ValueKey('perm-owner-manageRoles'));
    expect(ownerTile, findsOneWidget);
    expect(
        tester.widget<CheckboxListTile>(ownerTile).onChanged, isNull);
    expect(tester.widget<CheckboxListTile>(ownerTile).value, isTrue);

    // Grant the admins invoicing.
    final adminInvoicing =
        find.byKey(const ValueKey('perm-admin-issueInvoices'));
    await tester.scrollUntilVisible(adminInvoicing, 300,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CheckboxListTile>(adminInvoicing).value, isFalse);
    await tester.tap(adminInvoicing);
    await tester.pumpAndSettle();

    final stored =
        workspace.workspaces.single.rolePermissions['admin'] as List;
    expect(stored, contains('issueInvoices'));
    expect(
        tester.widget<CheckboxListTile>(adminInvoicing).value, isTrue);
  });

  testWidgets(
      'a plain ADMIN reads the matrix — their role highlighted, every '
      'checkbox disabled (#513)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember = workspace.myMember
        .copyWith(isOwner: false, isAdmin: true);
    await _pumpRoles(tester, workspace: workspace);

    expect(find.textContaining('Read-only'), findsOneWidget);
    expect(find.text('Your role'), findsOneWidget);
    final adminTile =
        find.byKey(const ValueKey('perm-admin-manageMembers'));
    expect(
        tester.widget<CheckboxListTile>(adminTile).onChanged, isNull);
    // The default admin set shows checked even though nothing stored.
    expect(tester.widget<CheckboxListTile>(adminTile).value, isTrue);
  });

  test('the fake repository refuses matrix edits without manageRoles, '
      'like set_role_permissions', () async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember = workspace.myMember
        .copyWith(isOwner: false, isAdmin: true);
    await expectLater(
      workspace.setRolePermissions(
          workspace.workspaces.single.id, 'member', const []),
      throwsA(isA<StateError>()),
    );
    // An active CO-OWNER holds manageRoles by default ("can have
    // less" — until the owner takes it away).
    workspace.myMember =
        workspace.myMember.copyWith(coOwner: CoOwnerStatus.active);
    await workspace.setRolePermissions(
        workspace.workspaces.single.id, 'member', const ['viewFinances']);
    expect(
      workspace.workspaces.single.rolePermissions['member'],
      ['viewFinances'],
    );
  });

  test('migration 0104 wires the helper, the RPC and the permission '
      'gates', () {
    // #749 — the two agreement permissions arrive with 0139.
    final sql = File('supabase/migrations/0104_role_permissions.sql')
            .readAsStringSync() +
        File('supabase/migrations/0139_negotiation_permissions.sql')
            .readAsStringSync() +
        File('supabase/migrations/0144_money_validation_parity.sql')
            .readAsStringSync();
    expect(sql, contains('role_permissions jsonb'));
    expect(sql, contains('has_permission'));
    expect(sql, contains('set_role_permissions'));
    // The catalog mirrors the Dart enum, name for name — the LATEST
    // set_role_permissions catalog array itself (#816: the 0104 array
    // lacked the two negotiation permissions while the file text
    // mentioned them elsewhere, and the RPC refused the client's own
    // payload with "unknown permission").
    final latest = File('supabase/migrations/0144_money_validation_parity.sql')
        .readAsStringSync();
    final catalog = RegExp(r"v_catalog text\[\] := array\[([^\]]+)\]")
        .firstMatch(latest)!
        .group(1)!;
    for (final permission in WorkspacePermission.values) {
      expect(catalog, contains("'${permission.wireName}'"),
          reason: '${permission.wireName} must be in the SQL catalog');
    }
    // Both invoicing RPCs consult the central permission now.
    expect(
        'has_permission'.allMatches(sql).length, greaterThanOrEqualTo(4));
    expect(sql, contains("public.has_permission(v_invoice.workspace_id, 'issueInvoices')"));
    expect(sql, contains("public.has_permission(p_workspace_id, 'issueInvoices')"));
  });
}
