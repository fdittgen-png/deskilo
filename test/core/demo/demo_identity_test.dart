// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — the Demo cast is a whole person, not an id.
//
// The evidence gathered for #1514 said the guides' images come from a
// real workspace and are cleaned afterwards by hand — a mechanism that
// had already let a member's telephone number reach the public wiki and
// every store build. The answer is to shoot in Demo instead, and the
// thing standing in the way was that Demo showed nobody: the cast's
// names were declared in `demoCast` and never reached a screen, because
// `Member` carries no name and `FakeProfileRepository` was built with no
// arguments — one row, called "Test User".
//
// So a members-directory screenshot taken in Demo showed "Test User" and
// four nameless monogram rows, and the contact block the guide exists to
// document was blank. These tests pin the seeding that fixes it.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_dataset.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every member the directory lists has a name', () async {
    final workspaces = FakeWorkspaceRepository.withWorkspace();
    seedDemoPeople(workspaces);

    final names = await workspaces.fetchMemberNames('ws-1');

    for (final person in demoCast) {
      expect(names[person.memberId], person.name,
          reason: '${person.memberId} is in the cast, so it must be on '
              'screen under its own name — a monogram row is what sent '
              'the last screenshot batch back to a real workspace');
    }
  });

  test('the contact block has something to show', () async {
    final workspaces = FakeWorkspaceRepository.withWorkspace();
    seedDemoPeople(workspaces);

    // Served only to an admin or owner, mirroring the member_emails gate
    // (0078) — and the visitor is the owner.
    final emails = await workspaces.fetchMemberEmails('ws-1');

    expect(emails, isNotEmpty);
    for (final entry in emails.entries) {
      expect(entry.value, endsWith('@example.test'),
          reason: 'RFC 2606 reserves .test, so a demonstration address '
              'can never reach a real mailbox however it is copied');
    }
  });

  test('the fixture gives the visitor a profile of their own', () {
    final fixture = DemoFixture.build();

    final mine = fixture.profiles.profiles
        .where((p) => p.id == fixture.profiles.myUserId);

    expect(mine, hasLength(1),
        reason: 'Settings, the profile sheet and an invoice recipient all '
            'read Profile; without one they render blank');
    expect(mine.single.displayName, demoCast.first.name);
    expect(mine.single.whatsapp, isNotEmpty);
  });

  test('a persona switch moves whose profile is mine', () {
    final fixture = DemoFixture.build();
    const member = DemoPersona.member;

    fixture.becomePersona(member);

    expect(fixture.profiles.myUserId, member.userId);
    final mine = fixture.profiles.profiles
        .singleWhere((p) => p.id == fixture.profiles.myUserId);
    expect(mine.displayName, member.person.name,
        reason: 'looking at the space as somebody else must show THEIR '
            'own name in Settings, not the owner\'s');
  });

  test('nothing in the cast could reach a real person', () {
    // The whole reason Demo can replace redaction: a value that escapes
    // in a screenshot belongs to nobody. `.test` is reserved (RFC 2606)
    // and +3363998xxxx is France's fictional range.
    for (final person in demoCast) {
      if (person.email.isNotEmpty) {
        expect(person.email, endsWith('@example.test'));
      }
      if (person.phone.isNotEmpty) {
        expect(person.phone, startsWith('+3363998'),
            reason: 'ARCEP reserves 06 39 98 xx xx for fiction; a real '
                'number in a guide image is exactly the defect #1514 '
                'was opened over');
      }
    }
  });
}
