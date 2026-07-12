// SPDX-License-Identifier: MIT
//
// #209: shared empty-state block — muted icon over a titleMedium title
// and an optional bodySmall subtitle, centered with the pinned metrics.
import 'package:deskilo/core/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpEmptyState(
  WidgetTester tester, {
  String? subtitle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.inbox_outlined,
          title: 'nothing here',
          subtitle: subtitle,
        ),
      ),
    ),
  );
}

void main() {
  test('metrics are pinned', () {
    expect(EmptyStateMetrics.iconSize, 48);
    expect(EmptyStateMetrics.padding, 24);
  });

  testWidgets('icon is muted and sized, title uses titleMedium',
      (tester) async {
    await pumpEmptyState(tester);
    final context = tester.element(find.byType(EmptyState));
    final theme = Theme.of(context);

    final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
    expect(icon.size, EmptyStateMetrics.iconSize);
    expect(icon.color, theme.colorScheme.onSurfaceVariant);

    final title = tester.widget<Text>(find.text('nothing here'));
    expect(title.style, theme.textTheme.titleMedium);

    expect(
      find.ancestor(
        of: find.text('nothing here'),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });

  testWidgets('no subtitle: only the title text renders', (tester) async {
    await pumpEmptyState(tester);

    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('subtitle renders muted in bodySmall', (tester) async {
    await pumpEmptyState(tester, subtitle: 'try again later');
    final context = tester.element(find.byType(EmptyState));
    final theme = Theme.of(context);

    final subtitle = tester.widget<Text>(find.text('try again later'));
    expect(subtitle.style?.fontSize, theme.textTheme.bodySmall?.fontSize);
    expect(subtitle.style?.color, theme.colorScheme.onSurfaceVariant);
  });
}
