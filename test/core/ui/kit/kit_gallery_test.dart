// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- every part of the kit on one page, through the experience
// guards: at 320, 390 and 1280 px, at text scale 1.0 and 1.3, light and dark,
// nothing overflows, one filled button at phone width, every control 48 dp
// and named. Each part takes its colours from the ambient Theme, so the same
// page passes under a scheme it has never seen (a seeded one). With SHEET=1
// it writes build/sheets/kit/*.png.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/ui/kit/bottom_action_bar.dart';
import 'package:deskilo/core/ui/kit/filter_chips.dart';
import 'package:deskilo/core/ui/kit/kit_card.dart';
import 'package:deskilo/core/ui/kit/result_page.dart';
import 'package:deskilo/core/ui/kit/select_row.dart';
import 'package:deskilo/core/ui/kit/split_bar.dart';
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/core/ui/kit/story.dart';
import 'package:deskilo/core/ui/kit/todo_row.dart';
import 'package:deskilo/core/ui/kit/two_line_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../../../ux/experience_guards.dart';

class _Gallery extends StatefulWidget {
  const _Gallery();

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  var _filter = 'open';
  var _legend = 1;
  var _picked = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final legend = [
      ('Not yet due', '6 invoices', 'CHF 2,941.00', scheme.outline),
      ('To confirm', '3 invoices', 'CHF 890.00', scheme.tertiary),
      ('Overdue', '8 invoices', 'CHF 1,761.00', scheme.error),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          KitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                const KitLabel('Owed to you'),
                const Text('CHF 5,592.00'),
                SplitBar(
                  parts: [
                    (weight: 2941, color: scheme.outline),
                    (weight: 890, color: scheme.tertiary),
                    (weight: 1761, color: scheme.error),
                  ],
                ),
                for (final (i, l) in legend.indexed)
                  LegendToggle(
                    key: ValueKey('kit-legend-$i'),
                    color: l.$4,
                    label: l.$1,
                    caption: l.$2,
                    value: l.$3,
                    selected: _legend == i,
                    onTap: () => setState(() => _legend = i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KitCard(
            child: Column(
              spacing: 10,
              children: [
                TodoRow(
                  icon: Icons.description_outlined,
                  title: 'Invoice October',
                  caption: '7 customers · CHF 2,341.00',
                  buttonLabel: 'Review',
                  buttonKey: const ValueKey('kit-todo-month'),
                  primary: true,
                  onPressed: () {},
                ),
                TodoRow(
                  icon: Icons.error_outline,
                  title: '1 e-invoice was rejected',
                  caption: '2026-0082 · E. Dubois · buyer reference missing',
                  buttonLabel: 'Fix',
                  buttonKey: const ValueKey('kit-todo-fix'),
                  alert: true,
                  onPressed: () {},
                ),
                const QuietLine('You are all caught up.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilterChips(
            options: [
              for (final f in ['open', 'overdue', 'confirm', 'paid'])
                (value: f, label: f, key: ValueKey('kit-chip-$f')),
            ],
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 12),
          RowList(
            rows: [
              for (final tone in StatusTone.values)
                TwoLineRow(
                  key: ValueKey('kit-row-${tone.name}'),
                  title: 'SASU KaloA',
                  caption: const Text('2 invoices · 50 days late'),
                  amount: 'CHF 200.00',
                  trailing: StatusChip(label: tone.name, tone: tone),
                  onTap: () {},
                ),
              SelectRow(
                key: const ValueKey('kit-select'),
                selected: _picked,
                onChanged: (v) => setState(() => _picked = v),
                title: 'Atelier Nord',
                caption: const Text('Flexible desk · 12 days'),
                amount: 'CHF 480.00',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A page with its main action under the thumb: the story and the bar.
Widget _page() => Scaffold(
  appBar: AppBar(title: const Text('Invoice 2026-0063')),
  bottomNavigationBar: BottomActionBar(
    actions: [
      OutlinedButton(
        key: const ValueKey('kit-record'),
        onPressed: () {},
        child: const Text('Record a payment'),
      ),
      FilledButton(
        key: const ValueKey('kit-send'),
        onPressed: () {},
        child: const Text('Share reminder 2'),
      ),
    ],
  ),
  body: ListView(
    padding: const EdgeInsets.all(12),
    children: const [
      KitCard(
        child: Story(
          lines: [
            (
              text: 'Issued · the customer sees it in their account',
              when: '7 Sep',
            ),
            (text: 'Due date', when: '21 Sep'),
          ],
          now: (text: 'Reminder 2 is due', when: 'Today'),
        ),
      ),
    ],
  ),
);

Widget _result() => Scaffold(
  body: ResultPage(
    title: '5 invoices issued',
    subtitle: 'Each customer sees theirs in their account.',
    done: const [(title: 'Atelier Nord', detail: '2026-0096', outcome: 'Sent')],
    notDone: const [
      (title: 'Kontor GmbH', detail: 'Billing address missing', outcome: ''),
    ],
    notDoneHeading: 'Not done',
    staysNote: 'It stays in To do until it is fixed.',
    doneLabel: 'Done',
    onDone: () {},
  ),
);

void main() {
  final themes = {
    'light': DeskiloTheme.light(),
    'dark': DeskiloTheme.dark(),
    'seeded': ThemeData(colorSchemeSeed: Colors.teal),
  };
  for (final (name, page) in [
    ('gallery', () => const _Gallery()),
    ('page', _page),
    ('result', _result),
  ]) {
    testWidgets('the kit $name passes the guards', (tester) async {
      await loadSheetFonts();
      final semantics = tester.ensureSemantics();
      final problems = <String, Set<String>>{};
      for (final MapEntry(key: themeName, value: theme) in themes.entries) {
        for (final scale in guardScales) {
          for (final width in guardWidths) {
            await pumpApp(
              tester,
              RepaintBoundary(
                child: Theme(data: theme, child: page()),
              ),
              size: Size(width, width < 600 ? 2600 : 1400),
              textScale: scale,
            );
            await tester.pumpAndSettle();
            final tag = '$width px, ×$scale, $themeName';
            for (final p in guardProblems(tester, width: width)) {
              problems.putIfAbsent(p, () => {}).add(tag);
            }
            if (scale == 1.0 && width != 320) {
              await writeSheet(
                tester,
                sheet: 'kit',
                name: '$name--${width.toInt()}--$themeName',
              );
            }
          }
        }
      }
      semantics.dispose();
      expect(problems, isEmpty);
    });
  }
}
