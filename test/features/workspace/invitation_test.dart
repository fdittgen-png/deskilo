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
      expect(de, contains('Workspace-ID'));
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
    Future<(List<Uri>, List<String>)> pumpSheet(
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
        code: 'GOODCODE22',
        role: InviteRole.user,
      ));
      await tester.pumpAndSettle();
      return (launched, shared);
    }

    testWidgets('WhatsApp without a phone opens wa.me with the message',
        (tester) async {
      final (launched, _) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched, hasLength(1));
      final uri = launched.single;
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], contains('GOODCODE22'));
      expect(uri.queryParameters['text'], contains(StoreLinks.play));
    });

    testWidgets('a typed phone routes WhatsApp and SMS to that number',
        (tester) async {
      final (launched, _) = await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('invite-phone')),
        '+33 6 12 34 56 78',
      );
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched.single.path, '/33612345678');
    });

    testWidgets('SMS carries the message in the body', (tester) async {
      final (launched, _) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-sms')));
      await tester.pumpAndSettle();

      final uri = launched.single;
      expect(uri.scheme, 'sms');
      expect(uri.queryParameters['body'], contains('GOODCODE22'));
    });

    testWidgets('share hands the full text to the share seam',
        (tester) async {
      final (_, shared) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-share')));
      await tester.pumpAndSettle();

      expect(shared.single, contains('GOODCODE22'));
      expect(shared.single, contains(StoreLinks.fdroid));
    });

    testWidgets('the language chips switch the message language',
        (tester) async {
      final (launched, _) = await pumpSheet(tester);

      await tester.tap(find.byKey(const ValueKey('invite-lang-fr')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();

      expect(launched.single.queryParameters['text'], contains('Bonjour'));
    });

    testWidgets('a first name lands in the greeting', (tester) async {
      final (launched, _) = await pumpSheet(tester);

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
