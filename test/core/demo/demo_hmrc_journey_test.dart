// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the London Demo, through the REAL composition (DeskiloRoot with the
// Demo entered): a visitor opens the UK VAT returns by a real link, connects
// HMRC (synthetic sign-in), submits the prepared return from the real screen,
// and reads the filed return back from the London store. The French space has
// no such door, an administrator is refused, and the other spaces never move.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/features/money/domain/mtd_boxes.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<(DemoJourney, ProviderContainer)> _open(
  WidgetTester tester, {
  required String space,
  required DemoPersona persona,
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.root
      .read(pendingDemoLinkProvider.notifier)
      .hold(DemoLink.parse({'space': space, 'persona': persona.name, 'to': '/vat-declarations'}));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
  return (journey, container);
}

Finder _mtd(String id) => find.byKey(ValueKey('vat-decl-mtd-$id'));

void main() {
  testWidgets('the owner connects, submits and reads back a filed return; the other spaces do not move', (tester) async {
    final (journey, container) = await _open(tester, space: 'london', persona: DemoPersona.owner);
    expect(container.read(currentWorkspaceProvider).value?.id, demoLondonSpaceId);
    expect(container.read(routerProvider).routeInformationProvider.value.uri.path, '/vat-declarations');
    final f = journey.fixture;
    final declaration = f.london.money.vatDeclarations.single;
    final frBefore = f.money.vatDeclarations.map((d) => (d.id, d.status)).toList();
    final deBefore = f.secondSpace.money.vatDeclarations.map((d) => (d.id, d.status)).toList();

    await tester.ensureVisible(_mtd(declaration.id));
    await tester.tap(_mtd(declaration.id));
    await tester.pumpAndSettle();
    // The nine boxes of the prepared return, derived from the invoices.
    final cents = mtdBoxCents(declaration);
    for (final field in mtdBoxFields) {
      expect(
        find.descendant(of: find.byKey(ValueKey('hmrc-box-$field')), matching: find.text(mtdBoxText(field, cents[field]!))),
        findsOneWidget,
        reason: field,
      );
    }
    expect(find.byKey(const ValueKey('hmrc-demo-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('hmrc-submit')), findsNothing, reason: 'not connected yet');

    await tester.tap(find.byKey(const ValueKey('hmrc-connect')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hmrc-submit')));
    await tester.pumpAndSettle();

    final filed = f.london.money.vatDeclarations.single;
    expect((filed.status, filed.submittedChannel), ('filed', 'hmrc_mtd'));
    expect(filed.submittedReceipt, startsWith('DEMO-'));
    expect(find.text(_en.hmrcFiledDemo(filed.submittedReceipt)), findsOneWidget);
    // The French and German spaces are exactly as they were.
    expect(f.money.vatDeclarations.map((d) => (d.id, d.status)).toList(), frBefore);
    expect(f.secondSpace.money.vatDeclarations.map((d) => (d.id, d.status)).toList(), deBefore);
    // One submission: the filed return offers no second.
    expect(find.byKey(const ValueKey('hmrc-submit')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('hmrc-submit'))).onPressed, isNull);
  });

  testWidgets('an administrator sees the door but is refused, and nothing is filed', (tester) async {
    final (journey, container) = await _open(tester, space: 'london', persona: DemoPersona.admin);
    expect(container.read(currentWorkspaceProvider).value?.id, demoLondonSpaceId);
    final declaration = journey.fixture.london.money.vatDeclarations.single;
    // Only the owner files VAT returns: the door may be shown, the connect is refused.
    if (_mtd(declaration.id).evaluate().isEmpty) {
      expect(container.read(routerProvider).routeInformationProvider.value.uri.path, isNot('/vat-declarations'),
          reason: 'the screen itself refuses an administrator');
      expect(declaration.isPrepared, isTrue);
      return;
    }
    await tester.ensureVisible(_mtd(declaration.id));
    await tester.tap(_mtd(declaration.id));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hmrc-connect')));
    await tester.pumpAndSettle();
    expect(find.text(_en.hmrcRefusalNotAllowed), findsOneWidget);
    expect(find.byKey(const ValueKey('hmrc-submit')), findsNothing);
    expect(journey.fixture.london.money.vatDeclarations.single.isPrepared, isTrue);
  });

  testWidgets('the French space has no door to HMRC', (tester) async {
    final (journey, container) = await _open(tester, space: 'pezenas', persona: DemoPersona.owner);
    expect(container.read(currentWorkspaceProvider).value?.id, 'ws-1');
    expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('vat-decl-mtd-')), findsNothing);
    expect(journey.fixture.london.money.vatDeclarations.single.isPrepared, isTrue);
  });
}
