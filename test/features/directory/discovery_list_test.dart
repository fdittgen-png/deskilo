// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Public discovery opens on a list, and a space is saved privately on this
// device under the signed-in person at their personal home.
//
// Invariant: the list is the first face and the map a disclosure; every row
// offers Bookmark and View as separate controls, met in reading order by a
// screen reader and by Tab; a saved place is written under the namespace of
// the canonical account at the personal home, is invisible to another
// account on the same device, survives a restart over the same store, and
// leaves at once when removed; at 360 dp the rows stack in one column.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/domain/saved_place.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _source = 'https://host.example';
const _one = PublicWorkspace('one', _source, 'sb_publishable_test', {
  'name': 'Office one',
  'address': '10 Main Street',
  'host_type': 'company',
  'description': 'Desks by the river, open from seven.',
});
const _two = PublicWorkspace('two', _source, 'sb_publishable_test', {
  'name': 'Office two',
  'address': '2 Side Street',
  'host_type': 'association',
});
const _three = PublicWorkspace('three', _source, 'sb_publishable_test', {
  'name': 'Office three',
  'host_type': 'person',
});

/// The namespace `standardTestOverrides` gives the fake account [user] at
/// the test home.
String _namespace(String user) => savedPlacesNamespaceOf(
      issuer: 'https://test.local/auth/v1',
      subject: user,
      home: 'inst-test',
    );

Key _row(PublicWorkspace w) => ValueKey('directory-row-${w.source}/${w.id}');
Key _bookmark(PublicWorkspace w) =>
    ValueKey('directory-bookmark-${w.source}/${w.id}');
Key _view(PublicWorkspace w) => ValueKey('directory-view-${w.source}/${w.id}');
Key _locate(PublicWorkspace w) =>
    ValueKey('directory-locate-${w.source}/${w.id}');

Future<void> _show(
  WidgetTester tester, {
  required InMemorySavedPlacesStore store,
  FakeAuthRepository? auth,
  Size? size,
  List<PublicWorkspace> cards = const [_one, _two, _three],
}) async {
  await pumpApp(
    tester,
    const DirectoryScreen(),
    size: size,
    overrides: standardTestOverrides(
      auth: auth ?? FakeAuthRepository.signedIn(),
      directory: FakeDirectoryRepository()..cards.addAll(cards),
      savedPlaces: store,
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the focused element is [finder] or sits inside it.
bool _focusWithin(WidgetTester tester, Finder finder) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  final focused = find.byElementPredicate((e) => e == context);
  return finder.evaluate().contains(context) ||
      find.ancestor(of: focused, matching: finder).evaluate().isNotEmpty;
}

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

void main() {
  testWidgets('the list is the first face and the map a disclosure', (
    tester,
  ) async {
    await _show(tester, store: InMemorySavedPlacesStore());
    expect(find.byType(DirectoryMap), findsNothing);
    expect(find.byKey(_row(_one)), findsOneWidget);
    expect(find.byKey(_bookmark(_one)), findsOneWidget);
    expect(find.byKey(_view(_one)), findsOneWidget);
    // The card is not a control: only its buttons are.
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('directory-portal-list')));
    await tester.pumpAndSettle();
    // The map provider is named before the map loads (#2555 C2).
    expect(find.byType(DirectoryMap), findsNothing);
    await tester.tap(find.byKey(const ValueKey('directory-map-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bookmark writes under the account at its personal home, and another '
    'account on the same device sees nothing of it',
    (tester) async {
      final store = InMemorySavedPlacesStore();
      await _show(tester, store: store);
      await tester.tap(find.byKey(_bookmark(_one)));
      await tester.pump();
      expect(find.text('Saved on this device'), findsOneWidget);
      expect(store.byNamespace.keys, [_namespace('user-1')]);
      expect(
        store.byNamespace[_namespace('user-1')]!.map((p) => (p.source, p.id)),
        [(_source, 'one')],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _show(
        tester,
        store: store,
        auth: FakeAuthRepository(userId: 'user-2'),
      );
      expect(find.text('Saved on this device'), findsNothing);
      expect(find.text('Bookmark'), findsNWidgets(3));
      expect(await store.read(_namespace('user-2')), isEmpty);
      expect(
        store.byNamespace.keys,
        [_namespace('user-1')],
        reason: 'reading as another account writes nothing',
      );
    },
  );

  testWidgets(
    'a saved place survives a restart over the same store, the Saved filter '
    'lists only it, and removing it is immediate',
    (tester) async {
      final store = InMemorySavedPlacesStore();
      await _show(tester, store: store);
      await tester.tap(find.byKey(_bookmark(_two)));
      await tester.pump();

      // A restart: a new scope over the same device store.
      await tester.pumpWidget(const SizedBox.shrink());
      await _show(tester, store: store);
      expect(
        find.descendant(
          of: find.byKey(_row(_two)),
          matching: find.text('Saved on this device'),
        ),
        findsOneWidget,
      );
      expect(find.text('Saved on this device'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('directory-saved-filter')));
      await tester.pump();
      expect(find.byKey(_view(_two)), findsOneWidget);
      expect(find.byKey(_view(_one)), findsNothing);
      expect(find.byKey(_view(_three)), findsNothing);

      await tester.tap(find.byKey(_bookmark(_two)));
      await tester.pump();
      expect(find.text('No places saved on this device yet.'), findsOneWidget);
      expect(find.byKey(_view(_two)), findsNothing);
      expect(store.byNamespace, isEmpty);
    },
  );

  testWidgets(
    'View opens the page, where Bookmark toggles the same saved list',
    (tester) async {
      final store = InMemorySavedPlacesStore();
      await _show(tester, store: store);
      await tester.tap(find.byKey(_view(_one)));
      await tester.pumpAndSettle();
      expect(find.byType(PublicWorkspaceView), findsOneWidget);
      final detailBookmark = find.byKey(
        const ValueKey('public-workspace-bookmark-$_source/one'),
      );
      expect(detailBookmark, findsOneWidget);
      expect(tester.widget<IconButton>(detailBookmark).isSelected, isFalse);
      await tester.tap(detailBookmark);
      await tester.pump();
      expect(tester.widget<IconButton>(detailBookmark).isSelected, isTrue);
      expect(store.byNamespace[_namespace('user-1')]!.single.id, 'one');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(_row(_one)),
          matching: find.text('Saved on this device'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('signed out, View still opens the page and nothing can be saved',
      (tester) async {
    await _show(
      tester,
      store: InMemorySavedPlacesStore(),
      auth: FakeAuthRepository(),
    );
    expect(find.byKey(_bookmark(_one)), findsNothing);
    expect(find.byKey(const ValueKey('directory-saved-filter')), findsNothing);
    await tester.tap(find.byKey(_view(_one)));
    await tester.pumpAndSettle();
    expect(find.byType(PublicWorkspaceView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('public-workspace-bookmark-$_source/one')),
      findsNothing,
    );
  });

  testWidgets('one column at 360 dp: the rows stack and nothing overflows', (
    tester,
  ) async {
    await _show(
      tester,
      store: InMemorySavedPlacesStore(),
      size: const Size(360, 800),
    );
    final one = tester.getRect(find.byKey(_row(_one)));
    final two = tester.getRect(find.byKey(_row(_two)));
    expect(one.width, lessThanOrEqualTo(360));
    expect(two.left, one.left);
    expect(two.top, greaterThanOrEqualTo(one.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a screen reader and the keyboard meet the name, Bookmark and View of '
    'one row before the next',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(
        tester,
        store: InMemorySavedPlacesStore(),
        cards: const [_one, _two],
      );
      final spoken = <String>[];
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label.isNotEmpty) spoken.add(data.label);
        if (data.tooltip.isNotEmpty) spoken.add(data.tooltip);
        for (final child in node.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        )) {
          visit(child);
        }
      }

      for (final view in RendererBinding.instance.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root != null) visit(root);
      }
      final nameOne = spoken.indexWhere((s) => s.startsWith('Office one'));
      final bookmarkOne = spoken.indexOf('Bookmark', nameOne + 1);
      final viewOne = spoken.indexOf('View', bookmarkOne + 1);
      final nameTwo = spoken.indexWhere(
        (s) => s.startsWith('Office two'),
        viewOne + 1,
      );
      expect(
        [nameOne, bookmarkOne, viewOne, nameTwo],
        everyElement(greaterThanOrEqualTo(0)),
        reason: spoken.join(' | '),
      );
      expect(
        nameOne < bookmarkOne && bookmarkOne < viewOne && viewOne < nameTwo,
        isTrue,
        reason: spoken.join(' | '),
      );

      // Tab reaches the first row's Bookmark, then its View, then Locate,
      // then the next row's Bookmark: no card swallows the focus.
      var tabs = 0;
      while (!_focusWithin(tester, find.byKey(_bookmark(_one))) && tabs < 12) {
        await _tab(tester);
        tabs++;
      }
      expect(_focusWithin(tester, find.byKey(_bookmark(_one))), isTrue);
      await _tab(tester);
      expect(_focusWithin(tester, find.byKey(_view(_one))), isTrue);
      await _tab(tester);
      expect(_focusWithin(tester, find.byKey(_locate(_one))), isTrue);
      await _tab(tester);
      expect(_focusWithin(tester, find.byKey(_bookmark(_two))), isTrue);
      semantics.dispose();
    },
  );
}
