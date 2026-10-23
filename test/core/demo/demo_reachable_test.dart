// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 — in the demo, a new discussion is not empty: the directory lists
// the active cast of both spaces (the persona left out, Ada and Bruno
// under both), the cast's group follows, and one letter suggests from it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/core/demo/seed/demo_people_seed.dart';
import 'package:deskilo/core/demo/seed/demo_reachable_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every persona is left out of its own directory, and only the '
      'active people of the spaces it is in are listed', () {
    final bruno = demoReachablePeople(DemoPersona.member.memberId);
    expect(bruno.map((p) => p.id), isNot(contains(DemoPersona.member.userId)));
    expect(
      bruno
          .where((p) => p.id == DemoPersona.owner.userId)
          .map((p) => p.workspaceId),
      ['ws-1', demoSecondSpaceId],
    );
    // Dov (pending) and Elise (paused) are not reachable.
    expect(
      bruno.map((p) => p.id),
      isNot(anyOf(contains('user-4'), contains('user-5'))),
    );
    // Chiara is only in the main space.
    final chiara = demoReachablePeople(DemoPersona.admin.memberId);
    expect(chiara.map((p) => p.workspaceId).toSet(), {'ws-1'});
    expect(demoReachablePeople(DemoPersona.kiosk.memberId), isEmpty);
  });

  testWidgets('the demo directory shows both spaces with counts and the '
      'group, and one letter suggests from it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final outer = ProviderContainer();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: outer,
        child: const DemoWorkspace(child: DeskiloApp()),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
        .read(routerProvider)
        .go('/account-messages');
    await tester.pumpAndSettle();

    // Ada (the owner persona) sees Bruno and Chiara at the Atelier, and
    // Jonas, Lena, Mehmet and Bruno at the Kontorhaus.
    expect(find.text('$demoSpaceName (2)'), findsOneWidget);
    expect(find.text('$demoSecondSpaceName (4)'), findsOneWidget);
    expect(find.text('Groups (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reachable-group-$demoGroupId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reachable-person--ws-1-user-1')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('account-messenger-portal-find-people-2')),
      'b',
    );
    await tester.pump();
    final suggested = tester
        .widgetList<ListTile>(
          find.descendant(
            of: find.byKey(const ValueKey('recipient-suggestions')),
            matching: find.byType(ListTile),
          ),
        )
        .map((t) => (t.title! as Text).data);
    expect(suggested, ['Bruno Kessler', 'Jonas Becker']);
    expect(find.text('$demoSpaceName, $demoSecondSpaceName'), findsOneWidget);
  });
}
