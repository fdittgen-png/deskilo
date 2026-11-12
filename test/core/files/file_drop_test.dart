// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3623 — a file dropped onto a place that takes a file goes to the SAME
// handler the picker's result goes to; another kind, several files, a
// folder, a second drop while one runs and a failed read are each refused
// in words; a phone has no zone at all.
import 'dart:async';
import 'package:deskilo/core/files/file_drop.dart';
import 'package:deskilo/core/files/file_drop_backend.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_drop.dart';

XFile _file(String name, {String? mime}) =>
    FakeDroppedFile(name, mimeType: mime);

const _xml = XTypeGroup(
  label: 'XML',
  extensions: ['xml'],
  mimeTypes: ['application/xml'],
);

void main() {
  late FakeFileDrop drop;
  late List<String> handled;
  Future<void> Function(XFile)? handler;

  setUp(() {
    drop = FakeFileDrop();
    handled = [];
    handler = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool available = true,
    bool enabled = true,
    String? wrongKind,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: drop.overrides(available: available),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FileDropZone(
              typeGroup: _xml,
              enabled: enabled,
              wrongKindMessage: wrongKind,
              onFile: (file) async {
                handled.add(file.name);
                await handler?.call(file);
              },
              child: const SizedBox.expand(child: Text('the place')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a dropped file of the right kind reaches the handler', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(DroppedItems([_file('Statement.XML')]));
    await tester.pump();
    expect(handled, ['Statement.XML']);
  });

  testWidgets('a file named only by its declared type is taken too', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(DroppedItems([_file('download', mime: 'application/xml')]));
    await tester.pump();
    expect(handled, ['download']);
  });

  testWidgets('another kind is refused with what the place takes', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(DroppedItems([_file('photo.png')]));
    await tester.pump();
    expect(handled, isEmpty);
    expect(find.textContaining('takes .xml files'), findsOneWidget);
  });

  testWidgets('another kind says the place\'s own sentence when it has one', (
    tester,
  ) async {
    await pump(tester, wrongKind: 'That is not a readable invoice.');
    drop.drop(DroppedItems([_file('photo.png')]));
    await tester.pump();
    expect(handled, isEmpty);
    expect(find.text('That is not a readable invoice.'), findsOneWidget);
  });

  testWidgets('several files are refused and none is taken', (tester) async {
    await pump(tester);
    drop.drop(DroppedItems([_file('a.xml'), _file('b.xml')]));
    await tester.pump();
    expect(handled, isEmpty);
    expect(find.text('Drop one file at a time.'), findsOneWidget);
  });

  testWidgets('a folder is refused', (tester) async {
    await pump(tester);
    drop.drop(DroppedItems([_file('folder.xml')], hasFolder: true));
    await tester.pump();
    expect(handled, isEmpty);
    expect(find.textContaining('folder cannot be dropped'), findsOneWidget);
  });

  testWidgets('dragging over shows the target and leaving removes it', (
    tester,
  ) async {
    await pump(tester);
    const overlay = ValueKey('file-drop-overlay');
    expect(find.byKey(overlay), findsNothing);
    drop.hover(over: true);
    await tester.pump();
    expect(find.byKey(overlay), findsOneWidget);
    expect(find.textContaining('This place takes .xml'), findsOneWidget);
    drop.hover(over: false);
    await tester.pump();
    expect(find.byKey(overlay), findsNothing);
  });

  testWidgets('a drop ends the hover', (tester) async {
    await pump(tester);
    drop.hover(over: true);
    await tester.pump();
    drop.drop(DroppedItems([_file('a.xml')]));
    await tester.pump();
    expect(find.byKey(const ValueKey('file-drop-overlay')), findsNothing);
  });

  testWidgets('a phone has no drop zone: the child alone', (tester) async {
    await pump(tester, available: false);
    expect(drop.present, isFalse);
    expect(find.text('the place'), findsOneWidget);
  });

  testWidgets('a disabled place ignores a drop', (tester) async {
    await pump(tester, enabled: false);
    drop.drop(DroppedItems([_file('a.xml')]));
    await tester.pump();
    expect(handled, isEmpty);
  });

  testWidgets('a second drop while the first file runs is refused', (
    tester,
  ) async {
    final running = Completer<void>();
    handler = (_) => running.future;
    await pump(tester);
    drop.drop(DroppedItems([_file('first.xml')]));
    await tester.pump();
    drop.hover(over: true);
    await tester.pump();
    // Busy: no invitation to drop.
    expect(find.byKey(const ValueKey('file-drop-overlay')), findsNothing);
    drop.drop(DroppedItems([_file('second.xml')]));
    await tester.pump();
    expect(find.textContaining('still being processed'), findsOneWidget);
    expect(handled, ['first.xml']);
    running.complete();
    await tester.pump();
    // Free again.
    drop.drop(DroppedItems([_file('third.xml')]));
    await tester.pump();
    expect(handled, ['first.xml', 'third.xml']);
  });

  testWidgets('a read that fails is said, and the zone takes the next file', (
    tester,
  ) async {
    handler = (file) async {
      if (file.name == 'broken.xml') throw StateError('unreadable');
    };
    await pump(tester);
    drop.drop(DroppedItems([_file('broken.xml')]));
    await tester.pump();
    expect(find.text('The dropped file could not be read.'), findsOneWidget);
    drop.drop(DroppedItems([_file('fine.xml')]));
    await tester.pump();
    expect(handled, ['broken.xml', 'fine.xml']);
  });

  group('what a place takes', () {
    test('by ending (case and dot ignored), by declared type, or anything', () {
      expect(dropTakes(_file('A.XML'), _xml), isTrue);
      expect(dropTakes(_file('a.csv'), _xml), isFalse);
      expect(dropTakes(_file('noending'), _xml), isFalse);
      expect(dropTakes(_file('x', mime: 'application/xml'), _xml), isTrue);
      expect(
        dropTakes(_file('a.XML'), const XTypeGroup(extensions: ['.xml'])),
        isTrue,
      );
      expect(dropTakes(_file('whatever'), const XTypeGroup()), isTrue);
    });

    test('the sentence part names the endings', () {
      expect(
        dropKindsOf(const XTypeGroup(extensions: ['png', 'jpg'])),
        '.png, .jpg',
      );
    });
  });
}
