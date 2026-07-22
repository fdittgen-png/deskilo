// SPDX-License-Identifier: 0BSD
//
// Personal invitations (0049): a ready-made download → account → join
// message sent over WhatsApp, SMS, or the share sheet, in the invitee's
// language; the owner can replace the built-in text with a {tag}
// template configured in workspace settings.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/share/text_sharer.dart';
import 'package:deskilo/features/workspace/domain/invitation_message.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/presentation/widgets/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Pezenas Cowork',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'GOODCODE22',
);

void main() {
  group('fillInvitationTemplate', () {
    test('replaces every known tag and blanks missing values', () {
      final text = fillInvitationTemplate(
        'Hi {firstName} {lastName}, join {workspaceName} '
        '({workspaceId}) via {inviteLink} — {downloadUrl} {phone} {role}',
        {
          'firstName': 'Alice',
          'workspaceName': 'Pezenas Cowork',
          'workspaceId': 'GOODCODE22',
          'inviteLink': 'deskilo://join?role=user&code=GOODCODE22',
          'downloadUrl': 'https://example',
          'role': 'Member',
        },
      );
      expect(text, contains('Hi Alice , join Pezenas Cowork'));
      expect(text, contains('(GOODCODE22)'));
      expect(text, contains('deskilo://join'));
      expect(text, contains('Member'));
      expect(text, isNot(contains('{')));
    });

    test('unknown tags survive so typos stay visible', () {
      expect(
        fillInvitationTemplate('Hello {tpyo}', const {}),
        'Hello {tpyo}',
      );
    });
  });

  group('buildInvitationMessage', () {
    test('default message localizes to the chosen language', () {
      final fr = buildInvitationMessage(
        workspace: _workspace,
        code: 'GOODCODE22',
        role: InviteRole.user,
        languageCode: 'fr',
        firstName: 'Alice',
      );
      expect(fr, contains('Bonjour Alice'));
      expect(fr, contains('GOODCODE22'));
      expect(fr, contains(StoreLinks.play));
      expect(fr, contains(StoreLinks.fdroid));
      expect(fr, contains('deskilo://join?role=user&code=GOODCODE22'));

      final de = buildInvitationMessage(
        workspace: _workspace,
        code: 'GOODCODE22',
        role: InviteRole.user,
        languageCode: 'de',
      );
      expect(de, contains('Hallo!'));
      expect(de, contains('Einladungscode'));
    });

    test('monospaceCode wraps the code in WhatsApp markers (#318)', () {
      final wa = buildInvitationMessage(
        workspace: _workspace,
        code: 'GOODCODE22',
        role: InviteRole.user,
        languageCode: 'en',
        monospaceCode: true,
      );
      expect(wa, contains('```GOODCODE22```'));
      // The deep link must stay unformatted — only the shown code wraps.
      expect(wa, contains('deskilo://join?role=user&code=GOODCODE22'));
    });

    test('custom template wins and its tags fill', () {
      final custom = _workspace.copyWith(
        invitationTemplate: 'Yo {firstName}, code {workspaceId}!',
      );
      expect(
        buildInvitationMessage(
          workspace: custom,
          code: 'GOODCODE22',
          role: InviteRole.user,
          languageCode: 'en',
          firstName: 'Bob',
        ),
        'Yo Bob, code GOODCODE22!',
      );
    });
  });

  group('invite sheet', () {
    Future<(List<Uri>, List<String>, FakeWorkspaceRepository)> pumpSheet(
      WidgetTester tester, {
      Workspace? workspace,
    }) async {
      final launched = <Uri>[];
      final shared = <String>[];
      final repo = FakeWorkspaceRepository.withWorkspace();
      if (workspace != null) repo.workspaces[0] = workspace;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(workspace: repo),
            linkLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return true;
            }),
            textSharerProvider.overrideWithValue((text) async {
              shared.add(text);
            }),
          ],
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      // Deliberately NOT awaited — the sheet future resolves on pop.
      unawaited(showInviteSheet(
        context,
        workspace: workspace ?? repo.workspaces.first,
        role: InviteRole.user,
      ));
      await tester.pumpAndSettle();
      return (launched, shared, repo);
    }

    testWidgets('WhatsApp mints a personal code (#319) and formats it '
        'monospace (#318) — never the workspace ID', (tester) async {
      final (launched, _, repo) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched, hasLength(1));
      final uri = launched.single;
      expect(uri.host, 'wa.me');
      final minted = repo.mintedInvitations.single;
      expect(minted.isAdmin, isFalse);
      final text = uri.queryParameters['text']!;
      expect(text, contains('```${minted.code}```'));
      expect(text, isNot(contains('GOODCODE22')));
      expect(text, contains(StoreLinks.play));
    });

    testWidgets('a typed phone routes WhatsApp and SMS to that number',
        (tester) async {
      final (launched, _, _) = await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('invite-phone')),
        '+33 6 12 34 56 78',
      );
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched.single.path, '/33612345678');
    });

    testWidgets('SMS carries the minted code UNformatted in the body',
        (tester) async {
      final (launched, _, repo) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-sms')));
      await tester.pumpAndSettle();

      final uri = launched.single;
      expect(uri.scheme, 'sms');
      final minted = repo.mintedInvitations.single;
      expect(uri.queryParameters['body'], contains(minted.code));
      expect(uri.queryParameters['body'], isNot(contains('```')));
    });

    testWidgets('share hands the full text to the share seam',
        (tester) async {
      final (_, shared, repo) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-share')));
      await tester.pumpAndSettle();

      expect(shared.single, contains(repo.mintedInvitations.single.code));
      expect(shared.single, contains(StoreLinks.fdroid));
    });

    testWidgets('a WhatsApp message pasted wholesale back into extractCode '
        'yields the minted code — the copy-tip round-trip (#318)',
        (tester) async {
      final (launched, _, repo) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      final text = launched.single.queryParameters['text']!;
      expect(
        InviteUriCodec.extractCode(text),
        repo.mintedInvitations.single.code,
      );
    });

    testWidgets('the typed names travel into the minted invitation (#319)',
        (tester) async {
      final (_, _, repo) = await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('invite-first-name')),
        'Alice',
      );
      await tester.enterText(
        find.byKey(const ValueKey('invite-last-name')),
        'Martin',
      );
      await tester.tap(find.byKey(const ValueKey('invite-share')));
      await tester.pumpAndSettle();

      final minted = repo.mintedInvitations.single;
      expect(minted.firstName, 'Alice');
      expect(minted.lastName, 'Martin');
    });

    testWidgets('the language chips switch the message language',
        (tester) async {
      final (launched, _, _) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-lang-fr')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched.single.queryParameters['text'], contains('Bonjour'));
    });

    testWidgets('a first name lands in the greeting', (tester) async {
      final (launched, _, _) = await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('invite-first-name')),
        'Alice',
      );
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched.single.queryParameters['text'], contains('Alice'));
    });
  });
}
