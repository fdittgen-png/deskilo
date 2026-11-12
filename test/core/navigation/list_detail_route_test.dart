// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3607 — a record's address beside its list: list → A → Back; a direct
// link to A → Close; a reload with A open; A → B → C by the arrow keys →
// Back; on a large window (the pane) and on a phone (a page). The list's
// state (its filter) survives every one of them.
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/navigation/list_detail_route.dart';
import 'package:deskilo/core/ui/kit/list_detail_scaffold.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ids = ['a', 'b', 'c'];

Finder _k(String key) => find.byKey(ValueKey(key));

class _List extends StatefulWidget {
  const _List({required this.selected});
  final String? selected;

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  final _filter = TextEditingController();
  late final _rows = {for (final id in _ids) id: FocusNode()};

  @override
  void dispose() {
    _filter.dispose();
    for (final f in _rows.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListDetailScaffold(
      id: 'test',
      paneStore: InMemoryPaneWidthStore(),
      selected: widget.selected,
      onClose: () => closeRecord(context, '/x'),
      order: () => _ids,
      onMove: (id) => moveToRecord(context, '/x', id),
      detail: (context, id) => Text('record $id', key: ValueKey('record-$id')),
      list: Column(
        children: [
          TextField(key: const ValueKey('filter'), controller: _filter),
          for (final id in _ids)
            Focus(
              focusNode: _rows[id],
              child: TextButton(
                key: ValueKey('row-$id'),
                onPressed: () => openRecord(context, '/x', id),
                child: Text('row $id'),
              ),
            ),
        ],
      ),
    ),
  );
}

GoRouter _router(String at) => GoRouter(
  initialLocation: at,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('home')),
    GoRoute(
      path: '/x',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: const ValueKey('/x'),
        child: OpenRecord(
          listPath: '/x',
          builder: (context, id) => _List(selected: id),
        ),
      ),
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => recordPage(
            context,
            state,
            (id) => Scaffold(body: Text('page $id', key: ValueKey('page-$id'))),
          ),
        ),
      ],
    ),
  ],
);

Future<GoRouter> _pump(WidgetTester tester, String at, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _router(at);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _at(GoRouter r) => r.routeInformationProvider.value.uri.path;

void main() {
  // As the app's router sets it: a push and a replace change the address.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  const desk = Size(1440, 900);
  const phone = Size(390, 844);

  testWidgets('on a desk: list → A opens the pane, the list keeps its '
      'filter, Back closes the pane', (tester) async {
    final r = await _pump(tester, '/x', desk);
    await tester.enterText(_k('filter'), 'kept');
    await tester.tap(_k('row-a'));
    await tester.pumpAndSettle();
    expect(_at(r), '/x/a');
    expect(_k('record-a'), findsOneWidget);
    expect(find.text('kept'), findsOneWidget);
    r.pop();
    await tester.pumpAndSettle();
    expect(_at(r), '/x');
    expect(_k('record-a'), findsNothing);
    expect(find.text('kept'), findsOneWidget);
  });

  testWidgets('a direct link to A shows the list with A beside it; Escape '
      'goes to the list\'s address and the keyboard back to a row', (
    tester,
  ) async {
    final r = await _pump(tester, '/x/a', desk);
    expect(_k('row-a'), findsOneWidget);
    expect(_k('record-a'), findsOneWidget);
    Focus.of(tester.element(_k('row-a'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_at(r), '/x');
    expect(_k('record-a'), findsNothing);
    expect(
      FocusManager.instance.primaryFocus,
      Focus.of(tester.element(_k('row-a'))),
    );
  });

  testWidgets('by the keyboard: Enter on a row opens the record beside it '
      'and the keyboard stays in the list; Escape closes it and the row '
      'keeps the keyboard', (tester) async {
    final r = await _pump(tester, '/x', desk);
    final row = Focus.of(tester.element(_k('row-b')));
    // The button inside the row takes the keyboard, as a Tab would.
    Focus.of(tester.element(find.text('row b'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_at(r), '/x/b');
    expect(_k('record-b'), findsOneWidget);
    final inList = FocusManager.instance.primaryFocus;
    expect(
      inList?.ancestors.contains(row) ?? false,
      isTrue,
      reason: 'the keyboard is still on row b',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_at(r), '/x');
    expect(FocusManager.instance.primaryFocus, inList);
  });

  testWidgets('A → B → C by the arrow keys replaces the record; one Back '
      'returns to the list', (tester) async {
    final r = await _pump(tester, '/x', desk);
    await tester.tap(_k('row-a'));
    await tester.pumpAndSettle();
    // Opened by a click: the arrow keys reach the scaffold all the same.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_at(r), '/x/b');
    expect(_k('record-b'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_at(r), '/x/c');
    r.pop();
    await tester.pumpAndSettle();
    expect(_at(r), '/x');
  });

  testWidgets('on a phone the record is a page over the list; Back returns '
      'to the list with its filter', (tester) async {
    final r = await _pump(tester, '/x', phone);
    await tester.enterText(_k('filter'), 'kept');
    await tester.tap(_k('row-a'));
    await tester.pumpAndSettle();
    expect(_at(r), '/x/a');
    expect(_k('page-a'), findsOneWidget);
    expect(_k('record-a'), findsNothing);
    r.pop();
    await tester.pumpAndSettle();
    expect(_at(r), '/x');
    expect(find.text('kept'), findsOneWidget);
  });

  testWidgets('a reload of a phone link to A shows the page, and Back goes '
      'to the list', (tester) async {
    final r = await _pump(tester, '/x/a', phone);
    expect(_k('page-a'), findsOneWidget);
    r.pop();
    await tester.pumpAndSettle();
    expect(_at(r), '/x');
    expect(_k('row-a'), findsOneWidget);
  });
}
