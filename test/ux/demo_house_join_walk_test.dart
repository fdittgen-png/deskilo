// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4008 — through the Demo's own screens: Bruno, a member of the
// organisation's other houses, finds Milan under the organisation on Me and
// asks to join it, after one question that says what joining means. Milan
// decides: the request waits for it. Where Milan welcomes the organisation's
// members, he is a member at once and Milan is one of his businesses. Ada,
// an owner, sets her house's welcome in Settings › Organisation.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;
import '../helpers/settings_sections.dart';
import '../helpers/shell_bar.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await _settle(tester);
  await tester.tap(target);
  await _settle(tester);
}

Future<void> _openMe(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/me');
  await _settle(tester);
}

const _organisation = 'demo-organisation-atelier';

void main() {
  testWidgets('Bruno asks Milan from Me, and the request waits for Milan', (
    tester,
  ) async {
    final journey = await pumpDemo(
      tester,
      persona: DemoPersona.member,
      openHub: false,
    );
    await _openMe(tester);
    final section = find.byKey(
      const ValueKey('me-other-houses-$_organisation'),
      skipOffstage: false,
    );
    expect(section, findsOneWidget);
    expect(
      find.descendant(
        of: section,
        matching: find.byKey(
          const ValueKey('me-other-house-$demoMilanSpaceId'),
        ),
      ),
      findsOneWidget,
      reason: 'Milan, the one house he is not a member of',
    );

    await _tap(
      tester,
      find.byKey(const ValueKey('house-join-$demoMilanSpaceId')),
    );
    // Nothing is sent before the question is answered.
    expect(find.byKey(const ValueKey('house-join-sheet')), findsOneWidget);
    final milan = journey.fixture.listings.firstWhere(
      (l) => l.id == demoMilanSpaceId,
    );
    expect(milan.memberOf(journey.fixture.actor.memberId), isNull);

    await _tap(tester, find.byKey(const ValueKey('house-join-confirm')));
    expect(
      milan.memberOf(journey.fixture.actor.memberId)?.status,
      MemberStatus.pending,
    );
    expect(
      find.byKey(
        const ValueKey('house-join-asked-$demoMilanSpaceId'),
        skipOffstage: false,
      ),
      findsOneWidget,
      reason: 'the request, waiting for Milan',
    );
  });

  testWidgets('a welcoming Milan takes Bruno at once', (tester) async {
    final journey = await pumpDemo(
      tester,
      persona: DemoPersona.member,
      openHub: false,
    );
    journey.fixture.houseWelcomes.add(demoMilanSpaceId);
    await _openMe(tester);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('me-other-house-$demoMilanSpaceId'),
          skipOffstage: false,
        ),
        matching: find.text('You will be a member at once'),
      ),
      findsOneWidget,
    );

    await _tap(
      tester,
      find.byKey(const ValueKey('house-join-$demoMilanSpaceId')),
    );
    await _tap(tester, find.byKey(const ValueKey('house-join-confirm')));

    final milan = journey.fixture.listings.firstWhere(
      (l) => l.id == demoMilanSpaceId,
    );
    expect(
      milan.memberOf(journey.fixture.actor.memberId)?.status,
      MemberStatus.active,
    );
    expect(
      find.byKey(
        const ValueKey('me-other-house-$demoMilanSpaceId'),
        skipOffstage: false,
      ),
      findsNothing,
      reason: 'no longer a house to ask',
    );
    expect(
      find.byKey(
        const ValueKey('me-space-pair-$demoMilanSpaceId'),
        skipOffstage: false,
      ),
      findsOneWidget,
      reason: 'Milan is one of his businesses now',
    );
  });

  testWidgets('Ada sets her house\'s welcome in Settings › Organisation', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, openHub: false);
    await tapShellBarControl(tester, 'shell-settings-button');
    await _settle(tester);
    await showWorkspaceSettings(tester);
    await revealInSettings(tester, find.text('Workspace'));
    await _tap(tester, find.text('Workspace'));
    await _tap(
      tester,
      find.byKey(const ValueKey('workspace-settings-organisation')),
    );
    final welcome = find.byKey(const ValueKey('house-welcome'));
    expect(tester.widget<SwitchListTile>(welcome).value, isFalse);
    await _tap(tester, welcome);
    expect(journey.fixture.houseWelcomes, contains(demoFirstSpaceId));
    expect(tester.widget<SwitchListTile>(welcome).value, isTrue);
  });
}
