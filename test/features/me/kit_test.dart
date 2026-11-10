// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the Me kit: each part renders in light and dark, a row is
// one button of at least 48 dp with its accessible name, the notice offers its
// Retry, and the hero card wears primary / onPrimary.
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:deskilo/features/me/presentation/kit/me_card.dart';
import 'package:deskilo/features/me/presentation/kit/me_notice.dart';
import 'package:deskilo/features/me/presentation/kit/me_quiet_line.dart';
import 'package:deskilo/features/me/presentation/kit/me_row.dart';
import 'package:deskilo/features/me/presentation/kit/me_section_label.dart';
import 'package:deskilo/features/me/presentation/kit/me_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool dark = false}) {
  final tokens = dark ? PersonalTheme.dark : PersonalTheme.light;
  return MaterialApp(
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      extensions: [tokens],
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
              const MeSectionLabel('Needs you'),
              MeCard(
                child: Column(
                  children: [
                    MeRow(
                      title: 'Invoice 2026-0412 · Atelier Nord',
                      subtitle: '100.00 € · due 30 Nov',
                      semanticLabel: 'Invoice 2026-0412 of Atelier Nord, 100.00 euros',
                      leading: const Icon(Icons.receipt_long_outlined),
                      trailing: const MeStatusChip(kind: MeChipKind.toPay, label: 'To pay'),
                      onTap: () => tapped++,
                    ),
                    const MeQuietLine('Nothing needs you right now.'),
                  ],
                ),
              ),
              MeNotice(
                text: 'One directory did not answer.',
                retryLabel: 'Try again',
                onRetry: () => retried++,
              ),
              const MeCard(tone: MeCardTone.hero, child: Text('Welcome')),
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
      final row = tester.getSize(find.byType(MeRow));
      expect(row.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(MeRow)).label,
        'Invoice 2026-0412 of Atelier Nord, 100.00 euros',
      );
    });
  }

  testWidgets('the hero card is primary with onPrimary text', (tester) async {
    await tester.pumpWidget(
      _host(const MeCard(tone: MeCardTone.hero, child: Text('Welcome'))),
    );
    final box = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(MeCard),
      matching: find.byType(DecoratedBox),
    ).first);
    expect((box.decoration as BoxDecoration).color, PersonalTheme.light.primary);
    final text = tester.widget<Text>(find.text('Welcome'));
    expect(DefaultTextStyle.of(tester.element(find.text('Welcome'))).style.color,
        PersonalTheme.light.onPrimary);
    expect(text.data, 'Welcome');
  });
}
