// SPDX-License-Identifier: MIT
//
// #210: shared inline banner — the #186 closed-day banner generalized.
// Structure: full width, AppRadius.mdAll container, severity-driven
// container/on-container colors, icon + text in the foreground color.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/app_radius.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpBanner(
  WidgetTester tester, {
  InlineBannerSeverity severity = InlineBannerSeverity.error,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: DeskiloTheme.light(),
      home: Scaffold(
        body: Column(
          children: [
            InlineBanner(
              key: const ValueKey('test-banner'),
              icon: Icons.event_busy,
              text: 'closed today',
              severity: severity,
            ),
          ],
        ),
      ),
    ),
  );
}

Container bannerContainer(WidgetTester tester) => tester.widget<Container>(
      find.descendant(
        of: find.byType(InlineBanner),
        matching: find.byType(Container),
      ),
    );

void main() {
  testWidgets('error severity: errorContainer fill, onErrorContainer '
      'icon and text, mdAll radius, full width', (tester) async {
    await pumpBanner(tester);
    final context = tester.element(find.byType(InlineBanner));
    final scheme = Theme.of(context).colorScheme;

    final decoration = bannerContainer(tester).decoration! as BoxDecoration;
    expect(decoration.color, scheme.errorContainer);
    expect(decoration.borderRadius, AppRadius.mdAll);

    final icon = tester.widget<Icon>(find.byIcon(Icons.event_busy));
    expect(icon.color, scheme.onErrorContainer);
    expect(icon.size, InlineBannerMetrics.iconSize);

    final text = tester.widget<Text>(find.text('closed today'));
    expect(text.style?.color, scheme.onErrorContainer);

    // Full width: the banner stretches to the column minus its margins.
    final bannerWidth = tester.getSize(find.byType(InlineBanner)).width;
    final bodyWidth = tester.getSize(find.byType(Column).first).width;
    expect(bannerWidth, bodyWidth);
  });

  testWidgets('info severity: muted surfaceContainerHighest fill with '
      'onSurfaceVariant foreground', (tester) async {
    await pumpBanner(tester, severity: InlineBannerSeverity.info);
    final context = tester.element(find.byType(InlineBanner));
    final scheme = Theme.of(context).colorScheme;

    final decoration = bannerContainer(tester).decoration! as BoxDecoration;
    expect(decoration.color, scheme.surfaceContainerHighest);

    final icon = tester.widget<Icon>(find.byIcon(Icons.event_busy));
    expect(icon.color, scheme.onSurfaceVariant);

    final text = tester.widget<Text>(find.text('closed today'));
    expect(text.style?.color, scheme.onSurfaceVariant);
  });

  testWidgets('caller key lands on the banner (call sites find it)',
      (tester) async {
    await pumpBanner(tester);
    expect(find.byKey(const ValueKey('test-banner')), findsOneWidget);
  });
}
