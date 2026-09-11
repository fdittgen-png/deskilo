// SPDX-License-Identifier: 0BSD
//
// Personal invitations (0049): a ready-made download → account → join
// message sent over WhatsApp, SMS, or the share sheet, in the invitee's
// language; the owner can replace the built-in text with a {tag}
// template configured in workspace settings.
import 'dart:async';
import 'dart:io';

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

    test('the chosen language\'s OWN template wins over the legacy '
        'single one; a language without one falls back (#486)', () {
      final custom = _workspace.copyWith(
        invitationTemplate: 'Legacy {firstName}',
        invitationTemplates: const {'fr': 'Salut {firstName} !'},
      );
      expect(
        buildInvitationMessage(
          workspace: custom,
          code: 'GOODCODE22',
          role: InviteRole.user,
          languageCode: 'fr',
          firstName: 'Léa',
        ),
        'Salut Léa !',
      );
      // German has no per-language template → legacy fallback.
      expect(
        buildInvitationMessage(
          workspace: custom,
          code: 'GOODCODE22',
          role: InviteRole.user,
          languageCode: 'de',
          firstName: 'Max',
        ),
        'Legacy Max',
      );
    });

    test('migration 0096 stores the columns the repository reads', () {
      final sql = File(
              'supabase/migrations/0096_workspace_language_and_invitations.sql')
          .readAsStringSync();
      expect(sql, contains('default_locale'));
      expect(sql, contains('invitation_templates'));
    });
  });

  group('invite sheet', () {
    Future<(List<Uri>, List<String>, FakeWorkspaceRepository)> pumpSheet(
      WidgetTester tester, {
      Workspace? workspace,
      bool environmentChoice = false,
    }) async {
      final launched = <Uri>[];
      final shared = <String>[];
      final repo = FakeWorkspaceRepository.withWorkspace(
        featureFlags: {
          if (environmentChoice) ...{
            'environmentPairs': true,
            'memberEnvironments': true,
          },
        },
      );
      // The flags live ON the workspace row, so a replacement row has to
      // carry them too — otherwise the override silently undoes them.
      final flags = <String, dynamic>{
        if (environmentChoice) ...{
          'environmentPairs': true,
          'memberEnvironments': true,
        },
      };
      if (workspace != null) {
        repo.workspaces[0] = workspace.copyWith(
          featureFlags: {...workspace.featureFlags, ...flags},
        );
      }
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

    // #1119 — the environment choice. Two answers and not three:
    // 0185's invariant is prod ⊆ dev, so the question is "does this
    // person touch production", never "which of two parallel worlds".
    testWidgets('a dev workspace with a twin offers production',
        (tester) async {
      final (_, _, repo) = await pumpSheet(
        tester,
        workspace: _workspace.copyWith(pairId: 'pair-1'),
        environmentChoice: true,
      );
      final toggle = find.byKey(const ValueKey('invite-also-prod'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse,
          reason: 'production is opted INTO, never the default');

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();
      expect(repo.mintedInvitations.single.alsoProd, isTrue);
    });

    testWidgets('without the choice, an invitation is dev-only',
        (tester) async {
      final (_, _, repo) = await pumpSheet(
        tester,
        workspace: _workspace.copyWith(pairId: 'pair-1'),
      );
      expect(find.byKey(const ValueKey('invite-also-prod')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('invite-whatsapp')));
      await tester.pumpAndSettle();
      expect(repo.mintedInvitations.single.alsoProd, isFalse,
          reason: 'the seven open invitations that predate #1119 must '
              'keep redeeming to dev exactly as they do now');
    });

    testWidgets('a workspace with no twin is not asked', (tester) async {
      // Asking a question with one possible answer is worse than not
      // asking it.
      await pumpSheet(tester, environmentChoice: true);
      expect(find.byKey(const ValueKey('invite-also-prod')), findsNothing);
    });

    testWidgets('the WORKSPACE language is the preselected message '
        'language (#486)', (tester) async {
      await pumpSheet(
        tester,
        workspace: _workspace.copyWith(defaultLocale: 'it'),
      );
      final chip = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('invite-lang-it')));
      expect(chip.selected, isTrue);
    });

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
