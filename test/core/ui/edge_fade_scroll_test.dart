// SPDX-License-Identifier: 0BSD
//
// #1184 — a chip row that scrolls has to say so.
//
// Four screens ended a filter row on a chip sliced in half by the
// screen edge. The rows did scroll; nothing said so, and a bisected
// chip reads as a rendering fault rather than as "there is more".
import 'package:deskilo/core/ui/edge_fade_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpRow(WidgetTester tester, int chips) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: EdgeFadeScroll(
            child: Row(
              children: [
                for (var i = 0; i < chips; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('Filter number $i'),
                      selected: false,
                      onSelected: (_) {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _fade => find.byType(ShaderMask);

void main() {
  testWidgets('a row that fits is not faded — the fade is information, '
      'not decoration', (tester) async {
    await pumpRow(tester, 1);
    expect(_fade, findsNothing);
  });

  testWidgets('a row that overflows fades at the end it continues past',
      (tester) async {
    await pumpRow(tester, 8);
    expect(_fade, findsOneWidget,
        reason: 'the last chip was being bisected with nothing to say '
            'there was more');
  });

  testWidgets('scrolled to the end, the fade moves to the side there is '
      'still content on', (tester) async {
    await pumpRow(tester, 8);
    final scrollable = find.byType(Scrollable);
    await tester.drag(scrollable, const Offset(-2000, 0));
    await tester.pumpAndSettle();

    final controller = Scrollable.of(tester.element(find.byType(FilterChip)
        .first));
    expect(controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 1),
        reason: 'the drag really did reach the end');
    // Still faded — but now on the LEFT, where the content it scrolled
    // past is. A row with content on both sides fades both.
    expect(_fade, findsOneWidget);
  });

  testWidgets('the row still scrolls and its chips still take a tap',
      (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: EdgeFadeScroll(
              child: Row(
                children: [
                  for (var i = 0; i < 8; i++)
                    FilterChip(
                      label: Text('Chip $i'),
                      selected: false,
                      onSelected: (_) => tapped = i,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A ShaderMask paints; it must not eat pointers.
    await tester.tap(find.text('Chip 0'));
    expect(tapped, 0);
  });
}
