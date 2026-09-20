// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1528 — defining a role a workspace invents for itself.
//
// #1287 shipped the database and deliberately no screen, so until this
// existed an owner could only define a role by calling the RPC. What the
// tests protect is that the editor refuses before the round trip exactly
// what 0247 refuses after it, and that a permission is CHOSEN from the
// catalogue rather than typed — the only shape in which an owner cannot
// ask for something the product does not have.
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:deskilo/features/workspace/presentation/widgets/role_editor_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<WorkspaceRole>> pumpEditor(
  WidgetTester tester, {
  WorkspaceRole? initial,
  String workspaceLocale = 'en',
}) async {
  // A tall viewport: the sheet lists every permission, and a Save that
  // is off-screen cannot be tapped. Width is pinned where it matters.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final saved = <WorkspaceRole>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RoleEditorSheet(
          initial: initial,
          workspaceLocale: workspaceLocale,
          onSave: (role) async => saved.add(role),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(RoleEditorSheet.saveKey)).onPressed !=
    null;

void main() {
  testWidgets('a role needs a key and a name in the language the space reads',
      (tester) async {
    await pumpEditor(tester);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(RoleEditorSheet.keyFieldKey),
      'treasurer',
    );
    await tester.pump();
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(RoleEditorSheet.nameKeyFor('en')),
      'Treasurer',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('the four built-in keys are refused, because they mean the same '
      'thing in every space', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(RoleEditorSheet.nameKeyFor('en')),
      'Something',
    );
    for (final key in WorkspaceRole.builtInKeys) {
      await tester.enterText(find.byKey(RoleEditorSheet.keyFieldKey), key);
      await tester.pump();
      expect(saveEnabled(tester), isFalse, reason: '"$key" is a built-in role');
    }
    await tester.enterText(
      find.byKey(RoleEditorSheet.keyFieldKey),
      'secretary',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('the key is an identifier, because the holders point at it',
      (tester) async {
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(RoleEditorSheet.nameKeyFor('en')),
      'Treasurer',
    );
    for (final bad in ['Treasurer', 't', 'has space', 'trésorier']) {
      await tester.enterText(find.byKey(RoleEditorSheet.keyFieldKey), bad);
      await tester.pump();
      expect(saveEnabled(tester), isFalse, reason: '"$bad" is not a key');
    }
  });

  testWidgets('an existing role does not offer its key', (tester) async {
    await pumpEditor(
      tester,
      initial: const WorkspaceRole(
        id: 'r',
        key: 'treasurer',
        names: {'en': 'Treasurer'},
      ),
    );
    expect(find.byKey(RoleEditorSheet.keyFieldKey), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('permissions are chosen from the catalogue, never typed',
      (tester) async {
    final saved = await pumpEditor(tester);
    await tester.enterText(
      find.byKey(RoleEditorSheet.keyFieldKey),
      'treasurer',
    );
    await tester.enterText(
      find.byKey(RoleEditorSheet.nameKeyFor('en')),
      'Treasurer',
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(RoleEditorSheet.permissionKeyFor(
        WorkspacePermission.issueInvoices,
      )),
    );
    await tester.tap(find.byKey(
      RoleEditorSheet.permissionKeyFor(WorkspacePermission.issueInvoices),
    ));
    await tester.pump();

    await tester.ensureVisible(find.byKey(RoleEditorSheet.saveKey));
    await tester.tap(find.byKey(RoleEditorSheet.saveKey));
    await tester.pumpAndSettle();

    expect(saved.single.permissions, {WorkspacePermission.issueInvoices});
    expect(saved.single.key, 'treasurer');
  });

  testWidgets('every permission the product has is offerable, and nothing '
      'else', (tester) async {
    await pumpEditor(tester);
    for (final permission in WorkspacePermission.values) {
      expect(
        find.byKey(RoleEditorSheet.permissionKeyFor(permission)),
        findsOneWidget,
        reason: '${permission.wireName} is in role_permission_catalog() and '
            'an owner must be able to grant it',
      );
    }
  });

  testWidgets('the space\'s own language is the one that must be filled in',
      (tester) async {
    await pumpEditor(tester, workspaceLocale: 'fr');
    await tester.enterText(
      find.byKey(RoleEditorSheet.keyFieldKey),
      'treasurer',
    );
    await tester.enterText(
      find.byKey(RoleEditorSheet.nameKeyFor('en')),
      'Treasurer',
    );
    await tester.pump();
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(RoleEditorSheet.nameKeyFor('fr')),
      'Trésorier',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  group('the rule the editor and the server share', () {
    test('names the same four refusals 0247 raises', () {
      const ok = WorkspaceRole(id: '', key: 'treasurer', names: {'en': 'T'});
      expect(roleProblem(ok, 'en'), isNull);
      expect(
        roleProblem(
          const WorkspaceRole(id: '', key: 'admin', names: {'en': 'T'}),
          'en',
        ),
        RoleProblem.builtIn,
      );
      expect(
        roleProblem(
          const WorkspaceRole(id: '', key: 'X', names: {'en': 'T'}),
          'en',
        ),
        RoleProblem.key,
      );
      expect(roleProblem(ok, 'fr'), RoleProblem.name);
    });
  });
}
