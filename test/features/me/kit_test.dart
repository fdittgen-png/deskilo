// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the Me kit: each part renders in light and dark, a row is
// one button of at least 48 dp with its accessible name, the notice offers its
// Retry, and the hero card wears primary / onPrimary.
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:deskilo/core/ui/kit/kit_card.dart';
import 'package:deskilo/core/ui/kit/retry_notice.dart';
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/core/ui/kit/tile_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool dark = false}) {
  final tokens = dark ? PersonalTheme.dark : PersonalTheme.light;
  return MaterialApp(
    // #3674 — the personal layer as Me applies it (layer_chrome.dart): the
    // scheme is the personal tokens.
    theme: personalThemeFrom(
      ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        extensions: [tokens],
      ),
    ),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('the parts render in ${dark ? 'dark' : 'light'}', (tester) async {
      var retried = 0;
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              const KitLabel('Needs you'),
              KitCard(
                child: Column(
                  children: [
                    TileRow(
                      title: 'Invoice 2026-0412 · Atelier Nord',
                      subtitle: '100.00 € · due 30 Nov',
                      semanticLabel: 'Invoice 2026-0412 of Atelier Nord, 100.00 euros',
                      leading: const Icon(Icons.receipt_long_outlined),
                      trailing: const StatusChip(tone: StatusTone.warn, label: 'To pay'),
                      onTap: () => tapped++,
                    ),
                    const QuietLine('Nothing needs you right now.'),
                  ],
                ),
              ),
              RetryNotice(
                text: 'One directory did not answer.',
                retryLabel: 'Try again',
                onRetry: () => retried++,
              ),
              const KitCard(tone: KitCardTone.hero, child: Text('Welcome')),
            ],
          ),
          dark: dark,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Invoice 2026-0412 · Atelier Nord'));
      await tester.tap(find.text('Try again'));
      expect(tapped, 1);
      expect(retried, 1);
      final row = tester.getSize(find.byType(TileRow));
      expect(row.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(TileRow)).label,
        'Invoice 2026-0412 of Atelier Nord, 100.00 euros',
      );
    });
  }

  testWidgets('the hero card is primary with onPrimary text', (tester) async {
    await tester.pumpWidget(
      _host(const KitCard(tone: KitCardTone.hero, child: Text('Welcome'))),
    );
    final box = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(KitCard),
      matching: find.byType(DecoratedBox),
    ).first);
    expect((box.decoration as BoxDecoration).color, PersonalTheme.light.primary);
    final text = tester.widget<Text>(find.text('Welcome'));
    expect(DefaultTextStyle.of(tester.element(find.text('Welcome'))).style.color,
        PersonalTheme.light.onPrimary);
    expect(text.data, 'Welcome');
  });
}
