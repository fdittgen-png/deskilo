// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4019 — the reader's role in words, from the membership in the current
// business: owner, co-owner, administrator (as the owner named it), a named
// role, member; nothing while the membership is unknown. The pages that
// name it are the routes that declare it, not a list of strings.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/shell/chrome_role.dart';
import 'package:deskilo/app/shell/space_chip.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_role.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_roles_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Member _member({
  bool owner = false,
  bool admin = false,
  CoOwnerStatus coOwner = CoOwnerStatus.none,
}) => Member(
  id: 'm-1',
  workspaceId: 'ws-1',
  userId: 'u-1',
  isAdmin: admin,
  isOwner: owner,
  coOwner: coOwner,
  status: MemberStatus.active,
);

const _administrator = WorkspaceRole(
  id: 'r-admin',
  key: 'admin',
  names: {'en': 'Manager', 'de': 'Leitung'},
  builtin: true,
);
const _accountant = WorkspaceRole(
  id: 'r-acc',
  key: 'accountant',
  names: {'en': 'Accountant', 'de': 'Buchhaltung'},
);

ChromeRole? _roleOf(
  Member? me, {
  List<WorkspaceRole> roles = const [],
  Map<String, Set<String>> held = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      myMemberProvider.overrideWith((ref) async => me),
      workspaceRolesProvider.overrideWith((ref) async => roles),
      workspaceRoleAssignmentsProvider.overrideWith((ref) async => held),
    ],
  );
  addTearDown(container.dispose);
  return container.read(chromeRoleProvider);
}

Future<ChromeRole?> _settled(
  Member? me, {
  List<WorkspaceRole> roles = const [],
  Map<String, Set<String>> held = const {},
}) async {
  final container = ProviderContainer(
    overrides: [
      myMemberProvider.overrideWith((ref) async => me),
      workspaceRolesProvider.overrideWith((ref) async => roles),
      workspaceRoleAssignmentsProvider.overrideWith((ref) async => held),
    ],
  );
  addTearDown(container.dispose);
  await container.read(myMemberProvider.future);
  await container.read(workspaceRolesProvider.future);
  await container.read(workspaceRoleAssignmentsProvider.future);
  return container.read(chromeRoleProvider);
}

String _words(ChromeRole? role, [String locale = 'en']) =>
    chromeRoleWords(lookupAppLocalizations(Locale(locale)), role!, locale);

void main() {
  test('nothing is said while the membership is unknown', () async {
    expect(_roleOf(null), isNull);
    expect(await _settled(null), isNull);
  });

  test('owner, co-owner, administrator and member, in words', () async {
    expect(_words(await _settled(_member(owner: true))), 'as owner');
    expect(
      _words(
        await _settled(_member(admin: true, coOwner: CoOwnerStatus.active)),
      ),
      'as co-owner',
    );
    expect(_words(await _settled(_member(admin: true))), 'as administrator');
    expect(_words(await _settled(_member())), 'as member');
    // A successor-in-waiting has no owner rights yet.
    expect(
      _words(await _settled(_member(coOwner: CoOwnerStatus.passive))),
      'as member',
    );
  });

  test('the administrator is called what the owner named it', () async {
    final role = await _settled(
      _member(admin: true),
      roles: const [_administrator],
    );
    expect(_words(role), 'as Manager');
    expect(_words(role, 'de'), 'als Leitung');
  });

  test('a member holding a role of the business reads its own name', () async {
    final role = await _settled(
      _member(),
      roles: const [_accountant],
      held: const {
        'm-1': {'r-acc'},
      },
    );
    expect(_words(role), 'as Accountant');
    expect(_words(role, 'de'), 'als Buchhaltung');
    expect(
      _words(role, 'fr'),
      'en tant que Accountant',
      reason: 'a name in no language of its own falls back to English',
    );
  });

  test('the words exist in the five languages', () async {
    final owner = await _settled(_member(owner: true));
    expect(_words(owner, 'de'), 'als Inhaber');
    expect(_words(owner, 'fr'), 'en tant que propriétaire');
    expect(_words(owner, 'es'), 'como propietario');
    expect(_words(owner, 'it'), 'come titolare');
  });

  test('the pages that name the role are declared by their routes', () {
    for (final path in [
      '/settings',
      '/workspace-settings',
      '/features',
      '/money',
      '/money/accounting',
      '/members',
      '/member/m-1',
      '/roles',
      '/invoices',
      '/invoice-register',
      '/deployment',
    ]) {
      expect(matchRoute(path)?.namesRole, isTrue, reason: path);
    }
    for (final path in [
      '/reserve',
      '/calendar',
      '/plan',
      '/events',
      '/me',
      '/me/account',
      '/workspace-overview',
    ]) {
      expect(matchRoute(path)?.namesRole ?? false, isFalse, reason: path);
    }
  });

  testWidgets('a page that does not declare it gets no words', (tester) async {
    BuildContext? seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myMemberProvider.overrideWith((ref) async => _member(owner: true)),
          workspaceRolesProvider.overrideWith((ref) async => const []),
          workspaceRoleAssignmentsProvider.overrideWith(
            (ref) async => const {},
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (c, ref, _) {
              seen = c;
              return Column(
                children: [
                  Text(chromeRoleFor(c, ref, '/reserve') ?? 'none'),
                  Text(chromeRoleFor(c, ref, '/settings') ?? 'none'),
                  Text(chromeRoleFor(c, ref, null) ?? 'none'),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen!.l10n.chromeRoleAs('x'), 'as x');
    expect(find.text('none'), findsNWidgets(2));
    expect(find.text('as owner'), findsOneWidget);
  });

  group('the chip on a phone', () {
    const space = Workspace(
      id: 'ws-1',
      name: 'Atelier du Marché',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'X',
      environment: 'prod',
    );

    Future<void> pumpChip(
      WidgetTester tester, {
      required String path,
      required double width,
    }) => pumpApp(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SpaceChip(tabTitle: 'Money', path: path),
          ),
        ),
      ),
      overrides: [
        currentWorkspaceProvider.overrideWith((ref) async => space),
        myWorkspacesProvider.overrideWith((ref) async => [space]),
        myOrganisationsProvider.overrideWith((ref) async => const []),
        myMemberProvider.overrideWith((ref) async => _member(owner: true)),
        workspaceRolesProvider.overrideWith((ref) async => const []),
        workspaceRoleAssignmentsProvider.overrideWith((ref) async => const {}),
      ],
    );

    String? line(WidgetTester tester) {
      final f = find.byKey(const ValueKey('space-chip-name'));
      return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
    }

    testWidgets('a consequential page names the role in the business line', (
      tester,
    ) async {
      await pumpChip(tester, path: '/money', width: 700);
      await tester.pumpAndSettle();
      expect(line(tester), 'DesKilo · Atelier du Marché · as owner');
    });

    testWidgets('Home names none', (tester) async {
      await pumpChip(tester, path: '/reserve', width: 700);
      await tester.pumpAndSettle();
      expect(line(tester), 'DesKilo · Atelier du Marché');
    });

    testWidgets('where the line would not fit with the role, the role goes '
        'first and the business stays; the page is whole', (tester) async {
      // Room for the avatar, the business line and the page, not the role
      // (the test font is one em wide for every letter).
      await pumpChip(tester, path: '/money', width: 480);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(line(tester), isNot(contains('as owner')));
      expect(find.text('Money'), findsOneWidget);
    });

    testWidgets('where not even the business fits, neither the role nor the '
        'business is shown, never the page\'s name', (tester) async {
      await pumpChip(tester, path: '/money', width: 120);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(line(tester), isNull);
      expect(find.text('Money'), findsOneWidget);
    });
  });
}
