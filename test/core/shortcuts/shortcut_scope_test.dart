// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — the app's keys: each app-wide key reaches the page on top; a bare
// key never fires while a text field has the focus (the Ctrl/⌘ ones do);
// the keys overlay lists exactly the registry's keys for the page; a page
// under another one hears nothing.
import 'package:deskilo/core/shortcuts/app_shortcuts.dart';
import 'package:deskilo/core/shortcuts/shortcut_scope.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _navigator = GlobalKey<NavigatorState>();

Future<List<AppShortcutId>> _pump(
  WidgetTester tester, {
  Set<AppShortcutId> bound = const {
    AppShortcutId.filter,
    AppShortcutId.newRecord,
    AppShortcutId.close,
    AppShortcutId.save,
    AppShortcutId.submit,
    AppShortcutId.print,
  },
  bool enabled = true,
}) async {
  final fired = <AppShortcutId>[];
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _navigator,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ShortcutHost(
        enabled: enabled,
        dialogContext: () => _navigator.currentContext,
        onSearch: () => fired.add(AppShortcutId.search),
        child: child!,
      ),
      home: ShortcutScope(
        handlers: {for (final id in bound) id: () => fired.add(id)},
        child: const Scaffold(
          body: Column(
            children: [
              TextField(key: ValueKey('field')),
              TextButton(
                key: ValueKey('button'),
                onPressed: null,
                child: Text('x'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return fired;
}

Future<void> _press(WidgetTester tester, AppShortcutId id) async {
  final chord = appShortcut(id).chords.first;
  final character = chord.character;
  if (character != null) {
    // `?` is Shift+/ on a US layout.
    final shifted = character == '?';
    if (shifted) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: character);
    if (shifted) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  } else {
    final mods = [
      if (chord.primary || chord.control) LogicalKeyboardKey.controlLeft,
      if (chord.alt) LogicalKeyboardKey.altLeft,
      if (chord.shift) LogicalKeyboardKey.shiftLeft,
    ];
    for (final m in mods) {
      await tester.sendKeyDownEvent(m);
    }
    await tester.sendKeyEvent(chord.key!);
    for (final m in mods.reversed) {
      await tester.sendKeyUpEvent(m);
    }
  }
  await tester.pump();
}

const _pageKeys = [
  AppShortcutId.filter,
  AppShortcutId.newRecord,
  AppShortcutId.close,
  AppShortcutId.save,
  AppShortcutId.submit,
  AppShortcutId.print,
];

void main() {
  testWidgets('each app-wide key reaches the page, wherever the keyboard is '
      'on it', (tester) async {
    final fired = await _pump(tester);
    for (final id in [AppShortcutId.search, ..._pageKeys]) {
      await _press(tester, id);
    }
    expect(fired, [AppShortcutId.search, ..._pageKeys]);
  });

  testWidgets('no bare key fires while a text field has the focus; the '
      'Ctrl/⌘ ones do', (tester) async {
    final fired = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    for (final id in [AppShortcutId.search, AppShortcutId.keys, ..._pageKeys]) {
      await _press(tester, id);
    }
    expect(fired, [
      AppShortcutId.search,
      AppShortcutId.save,
      AppShortcutId.submit,
      AppShortcutId.print,
    ]);
    expect(find.byKey(const ValueKey('shortcut-keys')), findsNothing);
  });

  testWidgets('? lists exactly the registry\'s keys for the page', (
    tester,
  ) async {
    await _pump(
      tester,
      bound: const {AppShortcutId.newRecord, AppShortcutId.print},
    );
    await _press(tester, AppShortcutId.keys);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shortcut-keys')), findsOneWidget);
    final listed = [
      for (final s in appShortcuts)
        if (find
            .byKey(ValueKey('shortcut-row-${s.id.name}'))
            .evaluate()
            .isNotEmpty)
          s.id,
    ];
    expect(listed, [
      AppShortcutId.search,
      AppShortcutId.keys,
      AppShortcutId.newRecord,
      AppShortcutId.print,
      AppShortcutId.openCalendar,
    ]);
    expect(find.text('Ctrl+K'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('a page under another page hears none of its keys', (
    tester,
  ) async {
    final fired = await _pump(tester);
    _navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    await _press(tester, AppShortcutId.newRecord);
    await _press(tester, AppShortcutId.search);
    expect(fired, [AppShortcutId.search]);
  });

  testWidgets('switched off, the app answers no key', (tester) async {
    final fired = await _pump(tester, enabled: false);
    await _press(tester, AppShortcutId.search);
    await _press(tester, AppShortcutId.keys);
    await tester.pumpAndSettle();
    expect(fired, isEmpty);
    expect(find.byKey(const ValueKey('shortcut-keys')), findsNothing);
  });

  test('the keys are written as the platform writes them', () {
    final search = appShortcut(AppShortcutId.search).chords.first;
    expect(search.label(TargetPlatform.windows), 'Ctrl+K');
    expect(search.label(TargetPlatform.macOS), '⌘K');
    expect(
      appShortcut(AppShortcutId.openCalendar).chords.first
          .label(TargetPlatform.linux),
      'Alt+↓',
    );
    expect({for (final s in appShortcuts) s.id}, AppShortcutId.values.toSet());
  });
}
