// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #887 — a managed profile from the admin's side: created with THE
// identity form, shown as managed on its page, handed over through a
// bound invitation (the sheet prefilled from the identity), and the
// handover revocable.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';

/// #1561 — an identity read the test holds open, so the edit form is
/// driven in the state the app really opens in: the screen mounted, the
/// identity still in flight. Settling the read first — what every other
/// test here does — is exactly what hid the defect.
class _GatedIdentity extends FakeWorkspaceRepository {
  _GatedIdentity() : super.withWorkspace();

  Completer<void> gate = Completer<void>();
  Object? failWith;
  int reads = 0;

  @override
  Future<PersonalInfo> managedIdentityOf(String memberId) async {
    reads++;
    await gate.future;
    if (failWith case final failure?) throw failure;
    return super.managedIdentityOf(memberId);
  }
}

Future<FakeWorkspaceRepository> _pumpMembers(WidgetTester tester,
    {FakeWorkspaceRepository? repository}) async {
  final workspace = repository ?? FakeWorkspaceRepository.withWorkspace();
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
  // #1307 — Members & plans sits in Administration, below This workspace.
  await tester.scrollUntilVisible(find.text('Members & plans'), 200,
      scrollable: find.byType(Scrollable).first);
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
    // #912 — a client with a company is named by the company.
    expect(find.text('SASU KaloA'), findsWidgets);
    expect(find.text('Managed'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-page-message')), findsNothing,
        reason: 'nobody reads a message to a managed member');

    // The page's ListView is not the only Scrollable (chips scroll too).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('member-page-managed-edit')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    // #912 — the company is the tile's title; the block beneath it
    // carries the address, no longer repeating the company.
    expect(
        find.text('Guilhem MARTIN, 209 rue Jean Bart, 31670 LABÈGE'),
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

  group('#1561 — the edit form never saves an identity it never loaded', () {
    const stored = PersonalInfo(
      firstName: 'Anne',
      lastName: 'Dupont',
      street: '12 rue des Lilas',
      postalCode: '34120',
      city: 'Pézenas',
      email: 'anne@example.org',
    );

    /// Opens the managed member's edit form with [workspace]'s identity
    /// read still in flight.
    Future<void> openEdit(
      WidgetTester tester,
      _GatedIdentity workspace,
      String name,
    ) async {
      await _pumpMembers(tester, repository: workspace);
      await tester.scrollUntilVisible(find.text(name), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('member-page-managed-edit')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('member-page-managed-edit')));
      // NOT pumpAndSettle: the loading view's spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a pending read shows no form, and the late identity is the '
        'one that gets edited', (tester) async {
      final workspace = _GatedIdentity();
      await workspace.createManagedMember('ws-1', stored);
      await openEdit(tester, workspace, 'Anne DUPONT');

      // In flight: nothing to type into, nothing to save. Before the fix
      // the form was mounted on PersonalInfo.empty right here.
      expect(find.byKey(const ValueKey('personal-info-first-name')),
          findsNothing);
      expect(find.byKey(const ValueKey('personal-info-save')), findsNothing,
          reason: 'Save may not be offered for a value never loaded');

      workspace.gate.complete();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Anne'), findsOneWidget,
          reason: 'the identity that arrived seeds the fields');

      await _type(tester, 'phone', '+33 6 12 34 56 78');
      await tester.tap(find.byKey(const ValueKey('personal-info-save')));
      await tester.pumpAndSettle();

      // One field changed; `update_managed_identity` replaces the whole
      // row, so every other field must still be in what was sent.
      final saved = workspace.otherMembers.single.managedIdentity;
      expect(saved.phone, '+33 6 12 34 56 78');
      expect(saved.firstName, 'Anne');
      expect(saved.lastName, 'Dupont');
      expect(saved.street, '12 rue des Lilas');
      expect(saved.postalCode, '34120');
      expect(saved.city, 'Pézenas');
      expect(saved.email, 'anne@example.org');
    });

    testWidgets('a transport failure says so and offers the read again, '
        'instead of reading as an empty identity', (tester) async {
      final workspace = _GatedIdentity()..failWith = Exception('offline');
      await workspace.createManagedMember('ws-1', stored);
      await openEdit(tester, workspace, 'Anne DUPONT');
      workspace.gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('personal-info-save')), findsNothing);
      expect(find.textContaining('could not be read'), findsOneWidget);

      // Try again re-reads; this time the server answers.
      workspace
        ..failWith = null
        ..gate = Completer<void>()
        ..gate.complete();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Anne'), findsOneWidget);
      expect(workspace.reads, greaterThan(1));
    });

    testWidgets('a refusal reads as a refusal, not as a blank form',
        (tester) async {
      final workspace = _GatedIdentity()
        ..failWith = const PostgrestException(
            message: 'not allowed to read this profile');
      await workspace.createManagedMember('ws-1', stored);
      await openEdit(tester, workspace, 'Anne DUPONT');
      workspace.gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('personal-info-save')), findsNothing);
      expect(find.textContaining('do not have the permission'), findsOneWidget);
      expect(find.text('Try again'), findsNothing,
          reason: 'a refusal is an answer; retrying it changes nothing');
    });
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
