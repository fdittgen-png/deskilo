// SPDX-License-Identifier: 0BSD
//
// #887 — a managed profile from the admin's side: created with THE
// identity form, shown as managed on its page, handed over through a
// bound invitation (the sheet prefilled from the identity), and the
// handover revocable.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pumpMembers(WidgetTester tester) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Members & plans'));
  await tester.pumpAndSettle();
  return workspace;
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(ValueKey('personal-info-$field')), text);
  await tester.pump();
}

void main() {
  testWidgets(
      'the admin creates a managed profile, lands on its page, hands it over',
      (tester) async {
    final workspace = await _pumpMembers(tester);

    await tester.tap(find.byKey(const ValueKey('members-add-managed')));
    await tester.pumpAndSettle();
    expect(find.textContaining('has no account yet'), findsOneWidget,
        reason: 'the form says whose data this is');

    await _type(tester, 'first-name', 'Guilhem');
    await _type(tester, 'last-name', 'Martin');
    await _type(tester, 'company', 'SASU KaloA');
    await _type(tester, 'street', '209 rue Jean Bart');
    await _type(tester, 'postal-code', '31670');
    await _type(tester, 'city', 'Labège');
    await tester.tap(find.byKey(const ValueKey('personal-info-save')));
    await tester.pumpAndSettle();

    final created = workspace.otherMembers.last;
    expect(created.isManaged, isTrue);
    expect(created.managedIdentity.company, 'SASU KaloA');
    expect(find.text('Managed profile created'), findsOneWidget);
    // Let that snack expire: the messenger queues the next behind it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Straight on the member page: named from the identity, marked.
    expect(find.text('Guilhem MARTIN'), findsWidgets);
    expect(find.text('Managed'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-page-message')), findsNothing,
        reason: 'nobody reads a message to a managed member');

    // The page's ListView is not the only Scrollable (chips scroll too).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('member-page-managed-edit')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SASU KaloA, 209 rue Jean Bart, 31670 LABÈGE'),
        findsOneWidget,
        reason: 'the identity tile shows the postal block');

    // Revoking calls the repository and confirms.
    await tester.tap(find.byKey(const ValueKey('member-page-revoke-handover')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(workspace.revokedHandovers, [created.id]);
    expect(find.text('Handover revoked'), findsOneWidget);
    await tester.pumpAndSettle();

    // Handing over opens the invite sheet prefilled from the identity;
    // the code it mints is bound to the member.
    await tester.tap(find.byKey(const ValueKey('member-page-hand-over')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Guilhem'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Martin'), findsOneWidget);
  });

  testWidgets('a bound invitation carries the member it hands over',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final id = await workspace.createManagedMember(
        'ws-1', const PersonalInfo(firstName: 'Anne', lastName: 'Dupont'));
    final code = await workspace.createInvitation('ws-1',
        isAdmin: false, memberId: id);
    expect(workspace.mintedInvitations.single.memberId, id);
    expect(code, isNotEmpty);
    await workspace.revokeHandover(id);
    expect(workspace.mintedInvitations, isEmpty);
  });
}
