// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3215 — a HelpRow keeps its help symbol in ONE column whatever follows it
// (a switch, a chevron, a value, nothing), at a phone and a desktop width, in
// the languages with the longest labels; the symbol stays a 48 dp target.
import 'package:deskilo/core/help/help_dot.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/ui/help_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _labels = {
  'en': 'Use the time zone of this device instead of the workspace',
  'fr': "Utiliser le fuseau horaire de l'appareil plutôt que celui de l'espace",
  'de': 'Die Zeitzone dieses Geräts statt der des Arbeitsbereichs verwenden',
  'it': "Usa il fuso orario del dispositivo invece di quello dell'area di lavoro",
  'es':
      'Usar la zona horaria de este dispositivo en lugar de la del espacio de trabajo',
};

Widget _rows(String label, List<bool> switchState) => Scaffold(
      body: ListView(
        children: [
          HelpRow.toggle(
            key: const ValueKey('row-switch'),
            title: label,
            value: switchState[0],
            onChanged: (v) => switchState[0] = v,
            leading: const Icon(Icons.public),
            topic: 'switch',
          ),
          HelpRow(
            key: const ValueKey('row-chevron'),
            title: label,
            leading: const Icon(Icons.language),
            topic: 'chevron',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          HelpRow(
            key: const ValueKey('row-value'),
            title: label,
            leading: const Icon(Icons.schedule),
            subtitle: const Text('24 h'),
            topic: 'value',
            onTap: () {},
          ),
          HelpRow(
            key: const ValueKey('row-none'),
            title: label,
            topic: 'none',
          ),
          const HelpRow(
            key: ValueKey('row-nohelp'),
            title: 'No symbol',
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );

void main() {
  for (final width in [360.0, 1192.0]) {
    for (final entry in _labels.entries) {
      testWidgets('${entry.key} at ${width.toInt()} dp: one help column',
          (tester) async {
        await pumpApp(
          tester,
          _rows(entry.value, [false]),
          size: Size(width, 1600),
          locale: Locale(entry.key),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        final dots = [
          for (final t in ['switch', 'chevron', 'value', 'none'])
            tester.getRect(find.byKey(ValueKey('help-dot-$t'))),
        ];
        for (final d in dots) {
          expect(d.left, closeTo(dots.first.left, 0.5));
          expect(d.width, greaterThanOrEqualTo(48));
          expect(d.height, greaterThanOrEqualTo(48));
        }
        // The title is whole: it wraps, it is never cut off.
        for (final k in ['switch', 'chevron', 'value', 'none']) {
          final title = tester.getRect(find.descendant(
            of: find.byKey(ValueKey('row-$k')),
            matching: find.text(entry.value),
          ));
          expect(title.right, lessThanOrEqualTo(dots.first.left + 0.5));
        }
        // A row without a symbol keeps its chevron in the same column as the
        // others': the trailing slot is shared.
        final chevron = tester.getRect(find.descendant(
            of: find.byKey(const ValueKey('row-chevron')),
            matching: find.byIcon(Icons.chevron_right)));
        final plain = tester.getRect(find.descendant(
            of: find.byKey(const ValueKey('row-nohelp')),
            matching: find.byIcon(Icons.chevron_right)));
        expect(plain.right, closeTo(chevron.right, 0.5));
      });
    }
  }

  testWidgets('the symbol opens the guide and the row keeps its own tap',
      (tester) async {
    final state = [false];
    final launched = <Uri>[];
    await pumpApp(
      tester,
      _rows('Label', state),
      size: const Size(360, 900),
      overrides: [
        linkLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(HelpDot), findsNWidgets(4));
    await tester.tap(find.byKey(const ValueKey('row-switch')));
    expect(state[0], isTrue);
    expect(launched, isEmpty);
    await tester.tap(find.byKey(const ValueKey('help-dot-chevron')));
    await tester.pump();
    expect(launched, hasLength(1));
  });
}
