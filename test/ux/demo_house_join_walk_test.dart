// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4008 — through the Demo's own screens: once Ada has added the house in
// Kraków, Bruno, a member of the organisation's other houses, finds it under
// the organisation on Me and asks to join it, after one question that says
// what joining means. The house decides: the request waits for it. Where the
// house welcomes the organisation's members, he is a member at once and it
// is one of his businesses. Ada sets her house's welcome in Settings ›
// Organisation.
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
  // Centred: at the end of Me the last row would stand under the edge.
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
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
  testWidgets(
    'Bruno asks the house in Kraków from Me, and the request waits for it',
    (tester) async {
      final journey = await pumpDemo(
        tester,
        persona: DemoPersona.member,
        openHub: false,
      );
      journey.fixture.revealHouse();
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
            const ValueKey('me-other-house-$demoHouseSpaceId'),
          ),
        ),
        findsOneWidget,
        reason: 'the house he is not a member of',
      );

      await _tap(
        tester,
        find.byKey(const ValueKey('house-join-$demoHouseSpaceId')),
      );
      // Nothing is sent before the question is answered.
      expect(find.byKey(const ValueKey('house-join-sheet')), findsOneWidget);
      final house = journey.fixture.listings.firstWhere(
        (l) => l.id == demoHouseSpaceId,
      );
      expect(house.memberOf(journey.fixture.actor.memberId), isNull);

      await _tap(tester, find.byKey(const ValueKey('house-join-confirm')));
      expect(
        house.memberOf(journey.fixture.actor.memberId)?.status,
        MemberStatus.pending,
      );
      expect(
        find.byKey(
          const ValueKey('house-join-asked-$demoHouseSpaceId'),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: 'the request, waiting for the house',
      );
    },
  );

  testWidgets('a welcoming house takes Bruno at once', (tester) async {
    final journey = await pumpDemo(
      tester,
      persona: DemoPersona.member,
      openHub: false,
    );
    journey.fixture
      ..revealHouse()
      ..houseWelcomes.add(demoHouseSpaceId);
    await _openMe(tester);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('me-other-house-$demoHouseSpaceId'),
          skipOffstage: false,
        ),
        matching: find.text('You will be a member at once'),
      ),
      findsOneWidget,
    );

    await _tap(
      tester,
      find.byKey(const ValueKey('house-join-$demoHouseSpaceId')),
    );
    await _tap(tester, find.byKey(const ValueKey('house-join-confirm')));

    final house = journey.fixture.listings.firstWhere(
      (l) => l.id == demoHouseSpaceId,
    );
    expect(
      house.memberOf(journey.fixture.actor.memberId)?.status,
      MemberStatus.active,
    );
    expect(
      find.byKey(
        const ValueKey('me-other-house-$demoHouseSpaceId'),
        skipOffstage: false,
      ),
      findsNothing,
      reason: 'no longer a house to ask',
    );
    expect(
      find.byKey(
        const ValueKey('me-space-pair-$demoHouseSpaceId'),
        skipOffstage: false,
      ),
      findsOneWidget,
      reason: 'the house is one of his businesses now',
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
    final toggle = find.descendant(of: welcome, matching: find.byType(Switch));
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await _tap(tester, welcome);
    expect(journey.fixture.houseWelcomes, contains(demoFirstSpaceId));
    expect(tester.widget<Switch>(toggle).value, isTrue);
  });
}
