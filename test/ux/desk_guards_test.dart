// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards guard: each rule fails a planted page
// that breaks it and passes one that keeps it. A stretched text and a button
// no key reaches fail; a 36 px row passes at the desk and fails for touch; a
// table whose rows the arrows walk passes; a dirty form asks before Escape
// discards it, a clean one closes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'experience_guards.dart';

class _Row extends StatelessWidget {
  const _Row({required this.height, this.focusNode});

  final double height;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: InkWell(
      focusNode: focusNode,
      onTap: () {},
      child: const Align(alignment: Alignment.centerLeft, child: Text('Row')),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pumpAndSettle();
}

Set<String> _problems(
  WidgetTester tester, {
  TargetPolicy policy = TargetPolicy.desk,
}) => deskGuardProblems(
  tester,
  kind: PageKind.document,
  size: const Size(1440, 900),
  policy: policy,
  rowTypes: const [_Row],
);

void main() {
  testWidgets('a stretched text fails', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const SizedBox(
        width: 1200,
        child: Text(
          'A sentence as wide as the window, with nothing to '
          'hold it to a reading measure, running on and on and on.',
        ),
      ),
    );
    expect(_problems(tester), contains('text wider than 760 px'));
    semantics.dispose();
  });

  testWidgets('a button no key reaches fails', (tester) async {
    final hidden = FocusNode(skipTraversal: true);
    addTearDown(hidden.dispose);
    await _pump(
      tester,
      Column(
        children: [
          FilledButton(onPressed: () {}, child: const Text('Reached')),
          FilledButton(
            focusNode: hidden,
            onPressed: () {},
            child: const Text('Never reached'),
          ),
        ],
      ),
    );
    expect(await keyboardProblems(tester), contains('unreachable by any key'));
  });

  testWidgets('a 36 px row passes at the desk and fails for touch; a 48 px '
      'row passes for touch', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, const _Row(height: 36));
    expect(_problems(tester), isNot(contains('row under 36 px')));
    expect(
      _problems(tester, policy: TargetPolicy.touch),
      contains('target under 48 dp'),
    );
    await _pump(tester, const _Row(height: 48));
    expect(_problems(tester, policy: TargetPolicy.touch), isEmpty);
    semantics.dispose();
  });

  testWidgets('a table whose rows the arrows walk passes: Tab enters once, '
      'the arrows reach every row', (tester) async {
    final rows = [for (var i = 0; i < 3; i++) FocusNode(skipTraversal: i > 0)];
    for (final n in rows) {
      addTearDown(n.dispose);
    }
    var at = 0;
    await _pump(
      tester,
      Focus(
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              at < rows.length - 1) {
            rows[++at].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [for (final n in rows) _Row(height: 48, focusNode: n)],
        ),
      ),
    );
    expect(await keyboardProblems(tester), isEmpty);
  });

  for (final dirty in [false, true]) {
    testWidgets(
      'Escape: a ${dirty ? 'dirty form asks first' : 'clean '
                'surface closes'}',
      (tester) async {
        await _pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => PopScope(
                  canPop: !dirty,
                  onPopInvokedWithResult: (popped, _) {
                    if (popped) return;
                    unawaited(
                      showDialog<void>(
                        context: dialog,
                        builder: (_) => const AlertDialog(
                          key: ValueKey('discard'),
                          content: Text('Discard?'),
                        ),
                      ),
                    );
                  },
                  child: const AlertDialog(content: Text('Form')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          await escapeProblems(
            tester,
            surfaces: find.byType(AlertDialog),
            dirty: dirty,
          ),
          isEmpty,
        );
      },
    );
  }
}
