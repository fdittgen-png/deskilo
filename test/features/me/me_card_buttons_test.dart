// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4131 -- the buttons of a business's card on Me never break a word: at 390
// and 320 px, at text 1.0 and 1.3, in the five languages, no label of a
// button is laid out with a line break inside a word, and the helper that
// says so fails on a label that is.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

/// The offsets at which [paragraph] breaks a line inside a word of [text].
List<int> brokenWords(RenderParagraph paragraph, String text) {
  final broken = <int>[];
  // Where each line after the first starts: the character at its left edge.
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
  )..layout(maxWidth: paragraph.size.width);
  addTearDown(painter.dispose);
  for (final line in painter.computeLineMetrics().skip(1)) {
    final y = line.baseline - line.ascent / 2;
    final start = painter.getPositionForOffset(Offset(0, y)).offset;
    if (start > 0 &&
        start < text.length &&
        text[start - 1] != ' ' &&
        text[start] != ' ') {
      broken.add(start);
    }
  }
  return broken;
}

/// Every label of the two buttons of the business, with its breaks.
Map<String, List<int>> _breaks(WidgetTester tester) {
  final out = <String, List<int>>{};
  for (final id in ['ws-1', 'ws-2']) {
    final texts = find.descendant(
      of: find.byKey(ValueKey('me-space-$id')),
      matching: find.byType(Text),
    );
    for (final element in texts.evaluate()) {
      final text = (element.widget as Text).data ?? '';
      final paragraph = element.renderObject! as RenderParagraph;
      out['$id|$text'] = brokenWords(paragraph, text);
    }
  }
  return out;
}

FakeWorkspaceRepository _pair() {
  final repo = twoSpaces();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    pairId: 'pair-1',
    environment: 'dev',
  );
  repo.workspaces[1] = repo.workspaces[1].copyWith(
    pairId: 'pair-1',
    environment: 'prod',
  );
  return repo;
}

void main() {
  testWidgets('the helper flags a word cut across two lines', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 40,
            child: Text('Testbetrieb', style: TextStyle(fontSize: 14)),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(brokenWords(paragraph, 'Testbetrieb'), isNotEmpty);
  });

  for (final code in ['en', 'fr', 'de', 'es', 'it']) {
    for (final scale in [1.0, 1.3]) {
      for (final width in [390.0, 320.0]) {
        testWidgets('$code, $width px, x$scale: no button breaks a word', (
          tester,
        ) async {
          tester.platformDispatcher.localesTestValue = [Locale(code)];
          tester.platformDispatcher.localeTestValue = Locale(code);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final router = await pumpMeApp(
            tester,
            workspace: _pair(),
            size: Size(width, 1800),
          );
          await goTo(tester, router, '/me');
          final breaks = _breaks(tester);
          expect(breaks, isNotEmpty);
          expect(
            breaks.entries.where((e) => e.value.isNotEmpty),
            isEmpty,
            reason: 'a word is cut: $breaks',
          );
          for (final id in ['ws-1', 'ws-2']) {
            final size = tester.getSize(find.byKey(ValueKey('me-space-$id')));
            expect(size.height, greaterThanOrEqualTo(48));
            expect(size.width, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('German at 390 px: Testbetrieb is on one line, stacked under '
      'the business button', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final router = await pumpMeApp(
      tester,
      workspace: _pair(),
      size: const Size(390, 1800),
    );
    await goTo(tester, router, '/me');
    final prod = find.byKey(const ValueKey('me-space-ws-2'));
    final dev = find.byKey(const ValueKey('me-space-ws-1'));
    expect(
      find.descendant(of: dev, matching: find.text('Testbetrieb')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(dev).dy,
      greaterThan(tester.getBottomLeft(prod).dy),
    );
    expect(tester.getTopLeft(dev).dx, tester.getTopLeft(prod).dx);
    expect(tester.getSize(dev).width, tester.getSize(prod).width);
  });
}
