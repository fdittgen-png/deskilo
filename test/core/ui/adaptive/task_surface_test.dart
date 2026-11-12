// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — a task opens in the container of the window (a sheet on
// a phone, a dialog on a tablet, a centred dialog or a side panel at the
// desk), stays ONE route when the window crosses a class (what was typed and
// the focus kept), and its form answers the keyboard: Enter submits a short
// form from a one-line field, Ctrl+Enter any form, never a multi-line
// field's Return or a word being composed; Escape asks before a changed task
// is dropped and closes an unchanged one at once.
import 'package:deskilo/core/ui/adaptive/task_surface.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = Size(390, 844);
const _tablet = Size(720, 1000);
const _desk = Size(1440, 900);

final _sheet = find.byKey(const ValueKey('task-sheet'));
final _dialog = find.byKey(const ValueKey('task-dialog'));
final _panel = find.byKey(const ValueKey('task-side-panel'));
final _name = find.byKey(const ValueKey('name'));
final _note = find.byKey(const ValueKey('note'));

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Probe {
  int submits = 0;
  bool? result;
  final routes = <Route<Object?>>[];
}

class _RouteCounter extends NavigatorObserver {
  _RouteCounter(this.probe);
  final _Probe probe;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) =>
      probe.routes.add(route);

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      probe.routes.remove(route);

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) =>
      probe.routes.remove(route);
}

Future<_Probe> _open(
  WidgetTester tester,
  TaskSize size, {
  WidgetBuilder? body,
}) async {
  final probe = _Probe();
  final name = TextEditingController();
  final note = TextEditingController();
  addTearDown(name.dispose);
  addTearDown(note.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [_RouteCounter(probe)],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              probe.result = await showTask<bool>(
                context,
                size: size,
                builder:
                    body ??
                    (_) => AppFormSheet(
                      title: 'New thing',
                      submitLabel: 'Save',
                      submitKey: const ValueKey('save'),
                      onSubmit: () async {
                        probe.submits++;
                        return null;
                      },
                      builder: (context, refresh) => [
                        AppTextField(
                          key: const ValueKey('name'),
                          controller: name,
                          label: 'Name',
                        ),
                        AppTextField(
                          key: const ValueKey('note'),
                          controller: note,
                          label: 'Note',
                          maxLines: 4,
                        ),
                      ],
                    ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return probe;
}

Future<void> _ctrlEnter(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('the container follows the window class', () {
    for (final (size, window, shown, bound) in [
      (TaskSize.short, _phone, _sheet, _phone.width),
      (TaskSize.short, _tablet, _dialog, TaskSurfaceMetrics.dialogMaxWidth),
      (TaskSize.short, _desk, _dialog, TaskSurfaceMetrics.dialogMaxWidth),
      (TaskSize.standard, _phone, _sheet, _phone.width),
      (TaskSize.standard, _tablet, _dialog, TaskSurfaceMetrics.dialogMaxWidth),
      (TaskSize.standard, _desk, _panel, TaskSurfaceMetrics.sidePanelWidth),
    ]) {
      testWidgets('${size.name} at ${window.width.toInt()}', (tester) async {
        _window(tester, window);
        await _open(tester, size);
        for (final other in [_sheet, _dialog, _panel]) {
          expect(
            other,
            identical(other, shown) ? findsOneWidget : findsNothing,
          );
        }
        final width = tester.getSize(find.byType(AppFormSheet)).width;
        expect(width, lessThanOrEqualTo(bound));
        if (identical(shown, _panel)) {
          expect(width, TaskSurfaceMetrics.sidePanelWidth);
          // On the right, the page beside it.
          expect(tester.getTopRight(_panel).dx, window.width);
        }
      });
    }
  });

  testWidgets('a resize across classes keeps the text, the focus and the one '
      'route', (tester) async {
    _window(tester, _phone);
    final probe = await _open(tester, TaskSize.standard);
    expect(probe.routes, hasLength(2));
    final task = probe.routes.last;
    await tester.enterText(_name, 'Ada');
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    for (final (window, shown) in [
      (_desk, _panel),
      (_tablet, _dialog),
      (_phone, _sheet),
      (_desk, _panel),
    ]) {
      _window(tester, window);
      await tester.pumpAndSettle();
      expect(shown, findsOneWidget);
      expect(probe.routes, hasLength(2));
      expect(identical(probe.routes.last, task), isTrue);
      expect(find.text('Ada'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: _name, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
    }
  });

  group('the keyboard', () {
    testWidgets('Enter submits a short form from a one-line field', (
      tester,
    ) async {
      _window(tester, _desk);
      final probe = await _open(tester, TaskSize.short);
      await tester.enterText(_name, 'Ada');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(probe.submits, 1);
      expect(probe.result, isTrue);
    });

    testWidgets('Enter does not submit a standard form; Ctrl+Enter does', (
      tester,
    ) async {
      _window(tester, _desk);
      final probe = await _open(tester, TaskSize.standard);
      await tester.enterText(_name, 'Ada');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(probe.submits, 0);
      expect(_panel, findsOneWidget);
      await _ctrlEnter(tester);
      expect(probe.submits, 1);
      expect(probe.result, isTrue);
    });

    testWidgets('Enter in a multi-line field is a new line, never a submit', (
      tester,
    ) async {
      _window(tester, _desk);
      final probe = await _open(tester, TaskSize.short);
      await tester.enterText(_note, 'one');
      final result = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // Not consumed: the field's own Return (a new line) gets it.
      expect(result, isFalse);
      expect(probe.submits, 0);
      await _ctrlEnter(tester);
      expect(probe.submits, 1);
    });

    testWidgets(
      'Enter and Ctrl+Enter while a word is composed submit nothing',
      (tester) async {
        _window(tester, _desk);
        final probe = await _open(tester, TaskSize.short);
        await tester.showKeyboard(_name);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'ka',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _ctrlEnter(tester);
        expect(probe.submits, 0);
        expect(_dialog, findsOneWidget);
      },
    );
  });

  group('leaving a task', () {
    final question = find.byKey(const ValueKey('unsaved-changes-dialog'));

    /// The five ways out, each as the person takes it.
    final ways = <String, Future<void> Function(WidgetTester)>{
      'Escape': (t) => t.sendKeyEvent(LogicalKeyboardKey.escape),
      'the scrim': (t) => t.tapAt(const Offset(8, 8)),
      'the back button': (t) => t.binding.handlePopRoute(),
      'Cancel': (t) => t.tap(find.byKey(const ValueKey('form-sheet-cancel'))),
      'a drag': (t) =>
          t.fling(find.text('New thing'), const Offset(0, 600), 3000),
    };

    for (final MapEntry(key: way, value: take) in ways.entries) {
      final window = way == 'a drag' ? _phone : _desk;

      testWidgets('$way closes an unchanged task at once', (tester) async {
        _window(tester, window);
        final probe = await _open(tester, TaskSize.standard);
        await take(tester);
        await tester.pumpAndSettle();
        expect(question, findsNothing);
        expect(probe.routes, hasLength(1));
      });

      testWidgets('$way on a changed task asks; keep stays, discard leaves', (
        tester,
      ) async {
        _window(tester, window);
        final probe = await _open(tester, TaskSize.standard);
        await tester.enterText(_name, 'Ada');
        await tester.pump();
        await take(tester);
        await tester.pumpAndSettle();
        expect(question, findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('unsaved-changes-keep')));
        await tester.pumpAndSettle();
        expect(find.text('Ada'), findsOneWidget);
        expect(probe.routes, hasLength(2));
        await take(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('unsaved-changes-discard')));
        await tester.pumpAndSettle();
        expect(probe.routes, hasLength(1));
        expect(probe.submits, 0);
      });
    }

    testWidgets('a Close after a completed submit does not ask', (
      tester,
    ) async {
      _window(tester, _desk);
      final field = TextEditingController();
      addTearDown(field.dispose);
      final probe = await _open(
        tester,
        TaskSize.standard,
        body: (context) => Column(
          children: [
            AppTextField(
              key: const ValueKey('name'),
              controller: field,
              label: 'Name',
            ),
            TextButton(
              onPressed: () => TaskSession.maybeOf(context)!.completed(),
              child: const Text('send'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('close'),
            ),
          ],
        ),
      );
      await tester.enterText(_name, 'Ada');
      await tester.tap(find.text('send'));
      await tester.pump();
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(question, findsNothing);
      expect(probe.routes, hasLength(1));
    });

    testWidgets('a letter typed into a raw field marks the task', (
      tester,
    ) async {
      _window(tester, _desk);
      await _open(
        tester,
        TaskSize.standard,
        body: (_) => const Material(child: TextField(key: ValueKey('raw'))),
      );
      await tester.tap(find.byKey(const ValueKey('raw')));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(question, findsOneWidget);
    });

    testWidgets('a task without a text field, marked changed, asks on '
        'Escape', (tester) async {
      _window(tester, _desk);
      await _open(
        tester,
        TaskSize.standard,
        body: (context) => Material(
          child: Switch(
            value: false,
            onChanged: (_) => TaskSession.maybeOf(context)!.markChanged(),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(question, findsOneWidget);
    });
  });
}
