// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — the long task: a page of its own with an address, the
// form in its column and a summary beside it from the expanded class (after
// the fields below it). The confirm button is in view at 390 and at 1440; a
// resize keeps what was typed and the focus; focus goes into the page and
// returns to what opened it; Escape, the close button and Back ask before
// typed work is lost (also text entered without key events); a deep link
// closes to its fallback; and the task ends with its context.
import 'package:deskilo/core/session/task_context.dart';
import 'package:deskilo/core/ui/adaptive/long_task_page.dart';
import 'package:deskilo/core/ui/adaptive/page_measure.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _phone = Size(390, 844);
const _desk = Size(1440, 900);

final _summaryBeside = find.byKey(const ValueKey('long-task-summary'));
final _summaryText = find.text('SUMMARY');
final _save = find.byKey(const ValueKey('save'));
final _first = find.byKey(const ValueKey('field-0'));
final _question = find.byKey(const ValueKey('unsaved-changes-dialog'));
final _opener = find.byKey(const ValueKey('opener'));

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Token extends Notifier<String> {
  @override
  String build() => 'person-a';

  void change(String next) => state = next;
}

final _token = NotifierProvider<_Token, String>(_Token.new);

class _Probe {
  int submits = 0;
  Object? result = 'unset';
}

Future<(_Probe, GoRouter)> _pump(
  WidgetTester tester, {
  String start = '/',
}) async {
  final probe = _Probe();
  final controllers = [for (var i = 0; i < 14; i++) TextEditingController()];
  addTearDown(() {
    for (final c in controllers) {
      c.dispose();
    }
  });
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            key: const ValueKey('opener'),
            onPressed: () async {
              probe.result = await showLongTask<bool>(
                context,
                address: '/task',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/task',
        builder: (context, state) => LongTaskPage(
          title: 'Big task',
          fallbackAddress: '/',
          summary: const Text('SUMMARY'),
          form: AppFormSheet(
            title: 'Big task',
            submitLabel: 'Save',
            submitKey: const ValueKey('save'),
            summary: const Text('SUMMARY'),
            onSubmit: () async {
              probe.submits++;
              return null;
            },
            builder: (context, refresh) => [
              for (var i = 0; i < controllers.length; i++)
                AppTextField(
                  key: ValueKey('field-$i'),
                  controller: controllers[i],
                  label: 'Field $i',
                ),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskContextTokenProvider.overrideWith((ref) => ref.watch(_token)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (probe, router);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_opener);
  await tester.pumpAndSettle();
}

/// Whether [finder] is wholly inside the window.
bool _inView(WidgetTester tester, Finder finder, Size window) {
  final box = tester.getRect(finder);
  return box.top >= 0 &&
      box.bottom <= window.height &&
      box.left >= 0 &&
      box.right <= window.width;
}

void main() {
  for (final window in [_phone, _desk]) {
    testWidgets('at ${window.width.toInt()} the confirm button is in view', (
      tester,
    ) async {
      _window(tester, window);
      await _pump(tester);
      await _open(tester);
      expect(_save, findsOneWidget);
      expect(_inView(tester, _save, window), isTrue);
      // Hittable: a tap reaches it and submits.
      await tester.tap(_save);
      await tester.pumpAndSettle();
      expect(_save, findsNothing);
    });
  }

  testWidgets('the summary is beside the form at 1440, after it at 390', (
    tester,
  ) async {
    _window(tester, _desk);
    await _pump(tester);
    await _open(tester);
    expect(_summaryBeside, findsOneWidget);
    expect(_summaryText, findsOneWidget);
    // The form keeps its column, the summary stands right of it.
    expect(tester.getSize(find.byType(AppFormSheet)).width, kFormColumnWidth);
    expect(
      tester.getTopLeft(_summaryBeside).dx,
      greaterThan(tester.getTopRight(find.byType(AppFormSheet)).dx),
    );

    _window(tester, _phone);
    await tester.pumpAndSettle();
    expect(_summaryBeside, findsNothing);
    await tester.scrollUntilVisible(
      _summaryText,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(_summaryText, findsOneWidget);
  });

  testWidgets('a resize keeps the typed text and the focus', (tester) async {
    _window(tester, _desk);
    await _pump(tester);
    await _open(tester);
    await tester.tap(_first);
    await tester.enterText(_first, 'Ada');
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    for (final size in [_phone, _desk, _phone]) {
      _window(tester, size);
      await tester.pumpAndSettle();
      expect(find.text('Ada'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focused));
    }
  });

  testWidgets('focus goes into the page and returns to the opener', (
    tester,
  ) async {
    _window(tester, _desk);
    await _pump(tester);
    await tester.tap(_opener);
    final openerFocus = FocusManager.instance.primaryFocus;
    await tester.pumpAndSettle();
    final inside = FocusManager.instance.primaryFocus!;
    expect(
      inside.context?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
      reason: 'the first field takes the focus',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_save, findsNothing);
    expect(FocusManager.instance.primaryFocus, same(openerFocus));
  });

  group('leaving typed work asks', () {
    final ways = <String, Future<void> Function(WidgetTester)>{
      'Escape': (t) => t.sendKeyEvent(LogicalKeyboardKey.escape),
      'the close button': (t) =>
          t.tap(find.byKey(const ValueKey('long-task-close'))),
      'the back button': (t) => t.binding.handlePopRoute(),
    };
    for (final MapEntry(key: way, value: take) in ways.entries) {
      testWidgets('$way closes an unchanged task at once', (tester) async {
        _window(tester, _desk);
        await _pump(tester);
        await _open(tester);
        await take(tester);
        await tester.pumpAndSettle();
        expect(_question, findsNothing);
        expect(_save, findsNothing);
      });

      testWidgets('$way on typed work asks; keep stays, discard leaves', (
        tester,
      ) async {
        _window(tester, _desk);
        await _pump(tester);
        await _open(tester);
        // Entered without a key event, as a phone's keyboard or dictation.
        await tester.enterText(_first, 'Ada');
        await tester.pump();
        await take(tester);
        await tester.pumpAndSettle();
        expect(_question, findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('unsaved-changes-keep')));
        await tester.pumpAndSettle();
        expect(find.text('Ada'), findsOneWidget);
        await take(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('unsaved-changes-discard')));
        await tester.pumpAndSettle();
        expect(_save, findsNothing);
      });
    }
  });

  testWidgets('a submit closes the page with true, without a question', (
    tester,
  ) async {
    _window(tester, _desk);
    final (probe, _) = await _pump(tester);
    await _open(tester);
    await tester.enterText(_first, 'Ada');
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_question, findsNothing);
    expect(probe.submits, 1);
    expect(probe.result, isTrue);
  });

  testWidgets('Ctrl+Enter submits a long form once', (tester) async {
    _window(tester, _desk);
    final (probe, _) = await _pump(tester);
    await _open(tester);
    await tester.tap(_first);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(probe.submits, 1);
  });

  testWidgets('a deep link closes to its fallback, asking first', (
    tester,
  ) async {
    _window(tester, _desk);
    final (_, router) = await _pump(tester, start: '/task');
    expect(_save, findsOneWidget);
    await tester.enterText(_first, 'Ada');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('long-task-close')));
    await tester.pumpAndSettle();
    expect(_question, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unsaved-changes-discard')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(_opener, findsOneWidget);
  });

  testWidgets('the task ends, unasked, when the person changes', (
    tester,
  ) async {
    _window(tester, _desk);
    await _pump(tester);
    await _open(tester);
    await tester.enterText(_first, 'Ada');
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LongTaskPage)),
    );
    container.read(_token.notifier).change('person-b');
    await tester.pumpAndSettle();
    expect(_question, findsNothing);
    expect(_save, findsNothing);
    expect(find.text('Ada'), findsNothing);
  });
}
