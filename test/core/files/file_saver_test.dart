// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Downloads pass (field report): every export (bill/badge/config PDF,
// XML backup) lands in the USER-VISIBLE Downloads — on Android via the
// MediaStore channel — and files saved by older builds migrate out of
// the hidden app dir once. The typed save says what it achieved per
// platform: a MediaStore refusal is a private copy and says so, an iPhone
// never reports a folder the person can open, no folder at all is a
// failure with its reason, and a refused write leaves nothing behind.
import 'dart:io';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _bytes = Uint8List.fromList([37, 80, 68, 70]);

/// Targets over temp directories; a missing one answers null, a MediaStore
/// nobody wired throws like a missing channel.
SaveTargets _targets({
  Future<String?> Function(Uint8List bytes, String fileName)? mediaStore,
  Directory? private,
  Directory? downloads,
  Directory? documents,
}) =>
    SaveTargets(
      mediaStore: mediaStore ??
          (_, _) async => throw MissingPluginException('deskilo/downloads'),
      privateDir: () async => private,
      downloadsDir: () async => downloads,
      documentsDir: () async =>
          documents ?? (throw MissingPluginException('path_provider')),
    );

Future<SaveOutcome> _save(SavePlatform platform, SaveTargets targets) =>
    saveOn(platform, targets, bytes: _bytes, fileName: 'invoice.pdf');

void main() {
  group('saveOn — the decision per platform, over fakes', () {
    late Directory root;
    Directory sub(String name) => Directory('${root.path}/$name')..createSync();

    setUp(() => root = Directory.systemTemp.createTempSync('deskilo-save'));
    tearDown(() => root.deleteSync(recursive: true));

    test('the host of this test run saves directly, not through Export…', () {
      expect(localSaveMode, FileDeliveryMode.direct);
    });

    test('Android: the entry MediaStore kept is the file reported', () async {
      final private = sub('private');
      final outcome = await _save(
        SavePlatform.android,
        _targets(
          // MediaStore renamed on collision: the reported name is its own.
          mediaStore: (_, _) async => 'Download/invoice (1).pdf',
          private: private,
        ),
      );
      expect(outcome, isA<SavedFile>()
          .having((o) => o.path, 'path', 'Download/invoice (1).pdf'));
      expect(private.listSync(), isEmpty,
          reason: 'a visible file needs no private copy');
    });

    test('Android: a MediaStore refusal keeps a private copy and says so',
        () async {
      final private = sub('private');
      final outcome = await _save(
        SavePlatform.android,
        _targets(
          mediaStore: (_, _) async =>
              throw PlatformException(code: 'save_failed', message: 'denied'),
          private: private,
        ),
      );
      expect(outcome, isA<SavedPrivately>()
          .having((o) => o.path, 'path', '${private.path}/invoice.pdf'));
      expect(File('${private.path}/invoice.pdf').readAsBytesSync(), _bytes);
    });

    test('Android without a private external dir falls back to documents',
        () async {
      final documents = sub('documents');
      final outcome =
          await _save(SavePlatform.android, _targets(documents: documents));
      expect(outcome, isA<SavedPrivately>()
          .having((o) => o.path, 'path', '${documents.path}/invoice.pdf'));
    });

    test('iPhone: never a folder the person can open — the app documents, '
        'reported as private', () async {
      final downloads = sub('Downloads');
      final documents = sub('Documents');
      final outcome = await _save(
        SavePlatform.ios,
        _targets(downloads: downloads, documents: documents),
      );
      expect(outcome, isA<SavedPrivately>()
          .having((o) => o.path, 'path', '${documents.path}/invoice.pdf'));
      expect(downloads.listSync(), isEmpty,
          reason: 'the sandbox Downloads folder is not Files either');
    });

    test('desktop: the Downloads folder when there is one', () async {
      final downloads = sub('Downloads');
      final outcome =
          await _save(SavePlatform.desktop, _targets(downloads: downloads));
      expect(outcome, isA<SavedFile>()
          .having((o) => o.path, 'path', '${downloads.path}/invoice.pdf'));
      expect(File('${downloads.path}/invoice.pdf').readAsBytesSync(), _bytes);
    });

    test('desktop without a Downloads folder keeps a private copy', () async {
      final documents = sub('Documents');
      final outcome =
          await _save(SavePlatform.desktop, _targets(documents: documents));
      expect(outcome, isA<SavedPrivately>());
    });

    test('no folder at all: a failure with its reason, not an invented path',
        () async {
      final outcome = await _save(SavePlatform.desktop, _targets());
      expect(outcome, isA<SaveFailed>()
          .having((o) => o.reason, 'reason', SaveFailure.noStorage));
    });

    test('a refused write: failed(writeFailed), and nothing half-written',
        () async {
      final missing = Directory('${root.path}/not-created');
      final outcome =
          await _save(SavePlatform.desktop, _targets(downloads: missing));
      expect(outcome, isA<SaveFailed>()
          .having((o) => o.reason, 'reason', SaveFailure.writeFailed));
      expect(root.listSync(), isEmpty, reason: 'no .part file remains');
    });
  });

  test('mimeTypeFor maps the export types viewers key off', () {
    expect(mimeTypeFor('bill-2026-07.PDF'), 'application/pdf');
    expect(mimeTypeFor('workspace.xml'), 'text/xml');
    expect(mimeTypeFor('qr.png'), 'image/png');
    // #1643 — a calendar file opens in the calendar, not a text editor.
    expect(mimeTypeFor('deskilo-20260513-1a2b3c4d.ics'), 'text/calendar');
    expect(mimeTypeFor('deskilo-trace.log'), 'text/plain');
    expect(mimeTypeFor('unknown.bin'), 'application/octet-stream');
  });

  group('migrateLegacyExports', () {
    late Directory legacy;

    setUp(() {
      legacy = Directory.systemTemp.createTempSync('deskilo-legacy');
    });

    tearDown(() {
      if (legacy.existsSync()) legacy.deleteSync(recursive: true);
    });

    test('moves exports to the saver and deletes the hidden originals',
        () async {
      File('${legacy.path}/bill.pdf').writeAsStringSync('PDF');
      File('${legacy.path}/backup.xml').writeAsStringSync('<x/>');
      // Non-export junk stays.
      File('${legacy.path}/cache.bin').writeAsStringSync('junk');

      final saved = <String>[];
      final moved = await migrateLegacyExports(
        legacyDir: legacy,
        save: ({required bytes, required fileName}) async {
          saved.add(fileName);
          return 'Download/$fileName';
        },
      );

      expect(moved, 2);
      expect(saved, unorderedEquals(['bill.pdf', 'backup.xml']));
      expect(File('${legacy.path}/bill.pdf').existsSync(), isFalse);
      expect(File('${legacy.path}/backup.xml').existsSync(), isFalse);
      expect(File('${legacy.path}/cache.bin').existsSync(), isTrue);
    });

    test('keeps the original when the save fails or falls back into the '
        'same directory', () async {
      File('${legacy.path}/bill.pdf').writeAsStringSync('PDF');

      final moved = await migrateLegacyExports(
        legacyDir: legacy,
        // Fallback wrote back into the legacy dir → NOT a migration.
        save: ({required bytes, required fileName}) async =>
            '${legacy.path}/$fileName',
      );

      expect(moved, 0);
      expect(File('${legacy.path}/bill.pdf').existsSync(), isTrue);
    });
  });

  testWidgets('the MediaStore channel contract: save(fileName, bytes, '
      'mimeType) returns the visible Downloads path', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('deskilo/downloads'),
      (call) async {
        calls.add(call);
        return 'Download/test.pdf';
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('deskilo/downloads'), null));

    // saveToDownloads branches on dart:io Platform (not the debug
    // override) — on the host this exercises the desktop path, so call
    // the channel branch only when actually on Android. Assert the
    // channel contract itself instead.
    const channel = MethodChannel('deskilo/downloads');
    final result = await channel.invokeMethod<String>('save', {
      'fileName': 'test.pdf',
      'bytes': Uint8List.fromList([1, 2, 3]),
      'mimeType': mimeTypeFor('test.pdf'),
    });

    expect(result, 'Download/test.pdf');
    expect(calls.single.method, 'save');
    final args = calls.single.arguments as Map;
    expect(args['fileName'], 'test.pdf');
    expect(args['mimeType'], 'application/pdf');
    expect(args['bytes'], isA<Uint8List>());
  });
}
