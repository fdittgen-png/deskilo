// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4226 — the Overview's list of things to do holds only what its reader may
// act on. The Demo practice (no places) opens on its Overview for everyone who
// enters it: the member does not meet the line to issue the month's invoices,
// the owner does, and it opens invoicing, never the calendar. Every line the
// list holds opens its own screen for the person who sees it.
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/presentation/screens/attention_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_practice_owner_walk.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('at ${size.width.toInt()} wide the practice\'s member meets no '
        'line to issue invoices, and every line opens its own screen', (
      tester,
    ) async {
      final (_, container, router) = await openDemoSpaceAsOwner(
        tester,
        space: 'practice',
        persona: 'member',
        size: size,
      );
      router.go('/workspace-overview');
      await _settle(tester);
      final lines = await container.read(attentionProvider.future);
      expect(
        lines.where((l) => l.action == AttentionAction.issue),
        isEmpty,
        reason: 'a member may not issue invoices',
      );
      for (final line in lines) {
        final route = attentionRoute(line);
        router.go(route);
        await _settle(tester);
        expect(
          router.routeInformationProvider.value.uri.path,
          Uri.parse(route).path,
          reason: '${line.action.name} opens its own screen, not another',
        );
      }
    });
  }

  testWidgets('the practice\'s owner meets the line, and it opens invoicing', (
    tester,
  ) async {
    final (_, container, router) = await openDemoSpaceAsOwner(
      tester,
      space: 'practice',
      size: const Size(1440, 900),
    );
    router.go('/workspace-overview');
    await _settle(tester);
    final lines = await container.read(attentionProvider.future);
    final issue = lines
        .where((l) => l.action == AttentionAction.issue)
        .toList();
    expect(issue, hasLength(1), reason: 'the owner may issue invoices');
    expect(issue.single.count, greaterThan(0));
    final route = attentionRoute(issue.single);
    router.go(route);
    await _settle(tester);
    expect(
      router.routeInformationProvider.value.uri.path,
      Uri.parse(route).path,
      reason: 'it opens invoicing, not the calendar',
    );
    expect(router.routeInformationProvider.value.uri.path, isNot('/calendar'));
  });
}
