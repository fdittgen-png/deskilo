// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — the privacy editor reads the personal home's network shape
// (`my_visibility_network_v1`, `my_personal_workspace_refs_v1`): chosen
// spaces are network references, named, told apart when two share a name,
// and a space on another installation says its verification is
// unavailable unless its membership fact is in force (#2558 C2: the
// checked writer takes network references). Widening lists the spaces
// added and removed.
import 'package:deskilo/features/me/application/me_actions.dart';
import 'package:deskilo/features/me/domain/audience_space.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _away = '1a2b3c4d-0000-4000-8000-0000025580ff';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

PersonalWorkspaceRef _here(FakeMeRepository me, String id, String label) =>
    PersonalWorkspaceRef(
      networkId: me.refOf(id),
      hostedHere: true,
      freshness: RefFreshness.local,
      status: RefStatus.active,
      label: label,
    );

PersonalWorkspaceRef _elsewhere(
  String id, {
  String? label,
  RefFreshness fresh = RefFreshness.unavailable,
}) =>
    PersonalWorkspaceRef(
      networkId: '$_away:$id',
      hostedHere: false,
      freshness: fresh,
      status: fresh == RefFreshness.unavailable ? null : RefStatus.active,
      label: label,
    );

Future<void> _account(WidgetTester tester, FakeMeRepository me) async {
  final router = await pumpMeApp(
    tester,
    workspace: FakeWorkspaceRepository(workspaces: []),
    me: me,
    extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
  );
  await goTo(tester, router, '/me/account');
}

Future<void> _openContact(WidgetTester tester) async {
  await tapIn(
    tester,
    'me-account-list',
    _key('visibility-field-contact_channels'),
  );
  await _tap(tester, _key('visibility-audience-chosen_spaces'));
}

void main() {
  late FakeMeRepository me;
  setUp(() {
    me = FakeMeRepository(
      accounts: {
        'user-1': FakeAccount(name: 'Test User', email: 'test@example.com'),
      },
    );
  });

  group('the network shape', () {
    test('my_visibility_network_v1: references and the home that answered', () {
      final home = me.homeInstallationId;
      final v = MyVisibility.fromJson({
        'home': {
          'installation_id': home,
          'roles': ['personal'],
        },
        'fields': {
          'contact_channels': {
            'audience': 'chosen_spaces',
            'workspace_refs': ['$home:ws-1', '$_away:ws-1'],
          },
        },
        'reachability': {'audience': 'nobody', 'workspace_refs': <String>[]},
        'about': {'profession': '', 'bio': ''},
      });
      expect(v.home, home);
      expect(v.of(VisibilityField.contactChannels).workspaces, {
        '$home:ws-1',
        '$_away:ws-1',
      }, reason: 'the same local id on two installations is two spaces');
      // #2558 C2 — the checked writer's `p_expected`: the references
      // sorted, none for an audience other than chosen spaces.
      expect(v.of(VisibilityField.contactChannels).expectedJson, {
        'audience': 'chosen_spaces',
        'workspace_refs': ['$_away:ws-1', '$home:ws-1']..sort(),
      });
      expect(
        const FieldAudience(VisibilityAudience.nobody, {'x:y'}).expectedJson,
        {'audience': 'nobody', 'workspace_refs': <String>[]},
      );
      expect(FieldAudience.isNetworkRef('$home:ws-1'), isTrue);
      expect(FieldAudience.isNetworkRef('ws-1'), isFalse, reason: 'unqualified');
    });

    test('a space is offered while the home knows an active or paused '
        'relationship now: its own row or a fact in force; names shared by '
        'two spaces are flagged', () {
      final spaces = [
        AudienceSpace.fromRef(_here(me, 'ws-1', 'Atelier')),
        AudienceSpace.fromRef(_elsewhere('ws-9', label: 'atelier ')),
        AudienceSpace.fromRef(_elsewhere('ws-8')),
        AudienceSpace.fromRef(
          PersonalWorkspaceRef(
            networkId: me.refOf('ws-3'),
            hostedHere: true,
            freshness: RefFreshness.local,
            status: RefStatus.exited,
            label: 'Gone',
          ),
        ),
        AudienceSpace.fromRef(_elsewhere('ws-7', fresh: RefFreshness.verified)),
        AudienceSpace.fromRef(_elsewhere('ws-6', fresh: RefFreshness.stale)),
      ];
      expect(
        [for (final s in spaces) s.selectable],
        [true, false, false, false, true, false],
      );
      expect(
        [for (final s in spaces) s.verified],
        [true, false, false, true, true, false],
      );
      expect(ambiguousNames(spaces), {me.refOf('ws-1'), '$_away:ws-9'});
    });

    test('the widening diff names added and removed spaces', () {
      const before = FieldAudience(VisibilityAudience.chosenSpaces, {'a', 'b'});
      const after = FieldAudience(VisibilityAudience.chosenSpaces, {'b', 'c'});
      final diff = FieldAudience.spacesDiff(before, after);
      expect(diff.added, ['c']);
      expect(diff.removed, ['a']);
      final widened = FieldAudience.spacesDiff(
        const FieldAudience(VisibilityAudience.mySpaces),
        after,
      );
      expect(widened.added, ['b', 'c']);
      expect(widened.removed, isEmpty);
    });

    test('the command sends network references to the checked writer: a '
        'verified space elsewhere is added, an unverified one and an '
        'unqualified id are refused, a saved one is kept on a narrowing', () async {
      final actions = MeActions(me, FakeLinkedMeRepository(), me);
      me.workspaceRefs = PersonalWorkspaceRefs(
        homeInstallationId: me.homeInstallationId,
        refs: [
          _here(me, 'ws-1', 'Atelier'),
          _elsewhere('ws-1', fresh: RefFreshness.verified),
          _elsewhere('ws-2', fresh: RefFreshness.stale),
        ],
      );
      final both = FieldAudience(VisibilityAudience.chosenSpaces, {
        me.refOf('ws-1'),
        '$_away:ws-1',
      });
      final saved = await actions.choose(
        VisibilityField.contactChannels,
        both,
        saved: await me.myVisibility(),
      );
      expect(saved!.of(VisibilityField.contactChannels), both,
          reason: 'the same local id on two installations is two spaces');

      final current = await me.myVisibility();
      await expectLater(
        actions.choose(
          VisibilityField.presence,
          const FieldAudience(VisibilityAudience.chosenSpaces, {'ws-1'}),
          saved: current,
        ),
        throwsA(isA<MeRefused>().having(
            (e) => e.reason, 'reason', MeRefusal.unqualifiedSpace)),
      );
      await expectLater(
        actions.choose(
          VisibilityField.presence,
          const FieldAudience(VisibilityAudience.chosenSpaces, {'$_away:ws-2'}),
          saved: current,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'a lapsed fact adds nothing',
      );
      expect(me.visibilityWrites, 1);

      // A saved space whose fact lapsed stays on a narrowing.
      me.accounts['user-1']!.visibility = current.withField(
        VisibilityField.presence,
        FieldAudience(VisibilityAudience.chosenSpaces,
            {'$_away:ws-2', me.refOf('ws-1')}),
      );
      final withStale = await me.myVisibility();
      await actions.choose(
        VisibilityField.presence,
        const FieldAudience(VisibilityAudience.chosenSpaces, {'$_away:ws-2'}),
        saved: withStale,
      );
      expect(
        (await me.myVisibility()).of(VisibilityField.presence).workspaces,
        {'$_away:ws-2'},
      );
    });
  });

  group('the privacy card', () {
    testWidgets('names the personal home, asks the three questions first and '
        'keeps the rest behind More sharing settings', (tester) async {
      await _account(tester, me);
      expect(_key('visibility-home'), findsOneWidget);
      expect(find.textContaining('Personal home: '), findsOneWidget);
      expect(find.text('Who can see my contact details?'), findsOneWidget);
      expect(find.text('Who can write to me?'), findsOneWidget);
      expect(find.text('Is my public profile published?'), findsOneWidget);
      expect(_key('visibility-field-identity'), findsNothing);
      expect(_key('visibility-about-edit'), findsNothing);
      await openMoreSharing(tester);
      expect(_key('visibility-field-identity'), findsOneWidget);
      expect(_key('visibility-field-about'), findsOneWidget);
      expect(_key('visibility-field-presence'), findsOneWidget);
      expect(_key('visibility-about-edit'), findsOneWidget);
    });

    testWidgets('spaces by reference: an ambiguous name says where, a space '
        'elsewhere is unverified and cannot be chosen; widening lists the '
        'spaces added and removed', (tester) async {
      me.workspaceRefs = PersonalWorkspaceRefs(
        homeInstallationId: me.homeInstallationId,
        refs: [
          _here(me, 'ws-1', 'Atelier'),
          _here(me, 'ws-2', 'Lyon'),
          _elsewhere('ws-1', label: 'Atelier'),
          _elsewhere('ws-8'),
        ],
      );
      await _account(tester, me);
      await _openContact(tester);

      final atelierHere = _key('visibility-space-${me.refOf('ws-1')}');
      expect(
        find.descendant(
          of: atelierHere,
          matching: find.text(
            'Same name as another space · on this personal home',
          ),
        ),
        findsOneWidget,
      );
      final atelierAway = _key('visibility-space-$_away:ws-1');
      expect(
        find.descendant(
          of: atelierAway,
          matching: find.text(
            'Verification unavailable · '
            'Same name as another space · on server 1a2b3c4d',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.widget<CheckboxListTile>(atelierAway).onChanged, isNull);
      final unnamed = _key('visibility-space-$_away:ws-8');
      expect(
        find.descendant(
          of: unnamed,
          matching: find.text('A workspace on another server'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<CheckboxListTile>(unnamed).onChanged, isNull);

      await _tap(tester, atelierHere);
      await _tap(tester, _key('visibility-save'));
      expect(find.text('Added: Atelier'), findsOneWidget);
      expect(_key('visibility-widen-removed'), findsNothing);
      await _tap(tester, _key('visibility-widen-confirm'));
      expect(
        me.accounts['user-1']!.visibility.of(VisibilityField.contactChannels),
        FieldAudience(VisibilityAudience.chosenSpaces, {me.refOf('ws-1')}),
      );

      // Swap one space for another: still a widening (Lyon is new), and the
      // question names both sides.
      await tapIn(
        tester,
        'me-account-list',
        _key('visibility-field-contact_channels'),
      );
      await tester.tap(atelierHere);
      await _tap(tester, _key('visibility-space-${me.refOf('ws-2')}'));
      await _tap(tester, _key('visibility-save'));
      expect(find.text('Added: Lyon'), findsOneWidget);
      expect(find.text('Removed: Atelier'), findsOneWidget);
      await _tap(tester, _key('visibility-widen-cancel'));
      expect(
        me.accounts['user-1']!.visibility.of(VisibilityField.contactChannels),
        FieldAudience(VisibilityAudience.chosenSpaces, {me.refOf('ws-1')}),
        reason: 'cancelling writes nothing',
      );
    });

    testWidgets('a field naming a space elsewhere can be changed now', (
      tester,
    ) async {
      me.accounts['user-1']!.visibility = MyVisibility.defaults.withField(
        VisibilityField.contactChannels,
        const FieldAudience(VisibilityAudience.chosenSpaces, {'$_away:ws-1'}),
      );
      await _account(tester, me);
      await tapIn(
        tester,
        'me-account-list',
        _key('visibility-field-contact_channels'),
      );
      await _tap(tester, _key('visibility-audience-nobody'));
      await _tap(tester, _key('visibility-save'));
      expect(
        me.accounts['user-1']!.visibility.of(VisibilityField.contactChannels),
        const FieldAudience(VisibilityAudience.nobody),
        reason: 'narrowing needs no confirmation and no verification',
      );
    });

    testWidgets('a refused save says so and keeps the saved value', (
      tester,
    ) async {
      me.spaceLabels['ws-1'] = 'Atelier';
      await _account(tester, me);
      me.failure = const PostgrestException(
        message: 'choose spaces you belong to',
      );
      await _openContact(tester);
      await _tap(tester, _key('visibility-space-${me.refOf('ws-1')}'));
      await _tap(tester, _key('visibility-save'));
      await _tap(tester, _key('visibility-widen-confirm'));
      expect(
        find.text('Could not save who sees this. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('visibility-field-contact_channels'),
          matching: find.text('Nobody'),
        ),
        findsOneWidget,
      );
      expect(
        me.accounts['user-1']!.visibility.of(VisibilityField.contactChannels),
        const FieldAudience(VisibilityAudience.nobody),
      );
    });

    testWidgets('spaces that cannot be listed offer a retry that lists them', (
      tester,
    ) async {
      me
        ..spaceLabels['ws-1'] = 'Atelier'
        ..refsFailure = const PostgrestException(message: 'unavailable');
      await _account(tester, me);
      await _openContact(tester);
      expect(_key('visibility-spaces-unavailable'), findsOneWidget);
      expect(_key('visibility-space-${me.refOf('ws-1')}'), findsNothing);

      me.refsFailure = null;
      await _tap(tester, 
        find.descendant(
          of: _key('visibility-spaces-unavailable'),
          matching: find.text('Try again'),
        ),
      );
      expect(_key('visibility-spaces-unavailable'), findsNothing);
      expect(_key('visibility-space-${me.refOf('ws-1')}'), findsOneWidget);
    });
  });
}
