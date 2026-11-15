// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4019 — the reference business as its owner and as a member, through the
// real composition: the same page, Settings, names the difference in the
// chrome. On the desk it follows the breadcrumb; on a phone it joins the
// chip's business line; on Home neither says it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

Future<void> _open(
  WidgetTester tester, {
  required DemoPersona persona,
  required String to,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.root
      .read(pendingDemoLinkProvider.notifier)
      .hold(
        DemoLink.parse({'space': 'pezenas', 'persona': persona.name, 'to': to}),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: journey.root,
      child: const DeskiloRoot(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _deskRole => find.byKey(const ValueKey('desk-crumb-role'));

String? _chipLine(WidgetTester tester) {
  final line = find.byKey(const ValueKey('space-chip-name'));
  return line.evaluate().isEmpty ? null : tester.widget<Text>(line).data;
}

void main() {
  const desk = Size(1280, 900);
  const phone = Size(830, 1200);

  testWidgets('on the desk, Settings names the owner after the breadcrumb', (
    tester,
  ) async {
    await _open(
      tester,
      persona: DemoPersona.owner,
      to: '/settings',
      size: desk,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('desk-breadcrumb')), findsOneWidget);
    expect(tester.widget<Text>(_deskRole).data, 'as owner');
  });

  testWidgets('on the desk, the same page names a member as a member', (
    tester,
  ) async {
    await _open(
      tester,
      persona: DemoPersona.member,
      to: '/settings',
      size: desk,
    );
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(_deskRole).data, 'as member');
  });

  testWidgets('on the desk, Home does not say it', (tester) async {
    await _open(tester, persona: DemoPersona.owner, to: '/reserve', size: desk);
    expect(find.byKey(const ValueKey('desk-breadcrumb')), findsOneWidget);
    expect(_deskRole, findsNothing);
  });

  testWidgets('on a phone, Home does not say it', (tester) async {
    await _open(
      tester,
      persona: DemoPersona.owner,
      to: '/reserve',
      size: phone,
    );
    expect(_chipLine(tester), isNotNull);
    expect(_chipLine(tester), isNot(contains('as owner')));
  });
}
