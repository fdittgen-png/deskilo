// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4129 -- inside a house of an organisation, the other houses and the house
// one is in are visible: at the desk with the sidebar open (its head is a
// menu), on the rail (the business one is in first, marked, no word cut), and
// on a phone (the title chip carries a mark). One list of houses for all
// three; a choice lands in that house without passing by Me.
import 'package:deskilo/app/shell/desk_navigation.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;

const _desk = Size(1440, 900);
const _phone = Size(390, 844);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// The Demo's other houses, from the data (never listed here).
Future<List<String>> _otherHouseIds(WidgetTester tester) async {
  final container = _container(tester);
  final current = container.read(currentWorkspaceProvider).value!;
  final organisations = await container.read(myOrganisationsProvider.future);
  final spaces = await container.read(myWorkspacesProvider.future);
  final known = {for (final s in spaces) s.id};
  return [
    for (final h in Organisation.othersOf(organisations, current.id))
      if (known.contains(h.workspaceId)) h.workspaceId,
  ];
}

void main() {
  testWidgets('desk, sidebar open: the head is a menu button, reached by Tab, '
      'listing the other houses with country and currency, and a choice '
      'lands in that house', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDemo(tester, size: _desk, openHub: false);
    final others = await _otherHouseIds(tester);
    expect(others, isNotEmpty);

    final head = find.byKey(const ValueKey('drawer-houses'));
    expect(head, findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-workspace-name')), findsOneWidget);
    expect(
      find.descendant(of: head, matching: find.byIcon(Icons.arrow_drop_down)),
      findsOneWidget,
      reason: 'the mark says it opens something',
    );
    expect(tester.getSize(head).height, greaterThanOrEqualTo(48));

    // Tab reaches it.
    var reached = false;
    for (var i = 0; i < 40 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus?.context;
      reached =
          focus != null &&
          (find
                  .descendant(of: head, matching: find.byWidget(focus.widget))
                  .evaluate()
                  .isNotEmpty ||
              focus.findAncestorWidgetOfExactType<TextButton>()?.key ==
                  const ValueKey('drawer-houses'));
    }
    expect(reached, isTrue, reason: 'Tab reaches the menu button');

    await tester.tap(head);
    await tester.pumpAndSettle();
    final items = find.byWidgetPredicate(
      (w) =>
          w is MenuItemButton &&
          (w.key as ValueKey?)?.value.toString().startsWith('drawer-house-') ==
              true,
    );
    // Every other house, then the way back to Me.
    expect(items, findsNWidgets(others.length + 1));
    expect(
      find.byKey(const ValueKey('drawer-house-back-to-me')),
      findsOneWidget,
    );
    for (final id in others) {
      final item = find.byKey(ValueKey('drawer-house-$id'));
      expect(item, findsOneWidget, reason: id);
      final label = tester
          .widgetList<Text>(
            find.descendant(of: item, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .join();
      expect(label, matches(RegExp(r'^.+ — .+ · [A-Z]{3}$')), reason: id);
    }

    final zurich = others.firstWhere((id) => id.contains('5'));
    await tester.tap(find.byKey(ValueKey('drawer-house-$zurich')));
    await tester.pumpAndSettle();
    expect(_container(tester).read(currentWorkspaceProvider).value?.id, zurich);
    semantics.dispose();
  });

  testWidgets('desk, rail: the business one is in comes first and is marked, '
      'every label is whole words, and a choice lands in that house', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpDemo(tester, size: _desk, openHub: false);
    await _container(tester)
        .read(deskRailCollapsedProvider.notifier)
        .set(collapsed: true);
    await tester.pumpAndSettle();
    final others = await _otherHouseIds(tester);
    final current = _container(tester).read(currentWorkspaceProvider).value!;

    final rail = find.byKey(const ValueKey('desk-rail'));
    expect(rail, findsOneWidget);
    final order = [
      for (final w
          in find
              .descendant(
                of: rail,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w.key is ValueKey<String> &&
                      RegExp(r'^rail-house-(?!line-)')
                          .hasMatch((w.key! as ValueKey<String>).value),
                ),
              )
              .evaluate())
        (w.widget.key! as ValueKey<String>).value.substring(
          'rail-house-'.length,
        ),
    ];
    expect(order.first, current.id, reason: 'the current business first');
    expect(order.skip(1).toSet(), others.toSet());
    final node = tester.getSemantics(
      find.byKey(ValueKey('rail-house-${current.id}')),
    );
    // ignore: deprecated_member_use
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(node.label, matches(RegExp(r'^.+ — .+ · [A-Z]{3}$')));
    for (final id in order) {
      final cell = find.byKey(ValueKey('rail-house-$id'));
      expect(tester.getSize(cell).height, greaterThanOrEqualTo(48), reason: id);
      expect(tester.getSize(cell).width, greaterThanOrEqualTo(48), reason: id);
    }

    final zurich = others.firstWhere((id) => id.contains('5'));
    await tester.tap(find.byKey(ValueKey('rail-house-$zurich')));
    await tester.pumpAndSettle();
    expect(_container(tester).read(currentWorkspaceProvider).value?.id, zurich);
    semantics.dispose();
  });

  testWidgets('phone: the chip shows its mark inside the Demo\'s head, 48 dp, '
      'and a business in no organisation shows none', (tester) async {
    await pumpDemo(tester, size: _phone, openHub: false);
    final chip = find.byKey(const ValueKey('space-chip-houses'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(
        of: chip,
        matching: find.byKey(const ValueKey('space-chip-mark')),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
