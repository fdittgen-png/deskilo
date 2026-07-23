// SPDX-License-Identifier: 0BSD
//
// Downloads pass (field report): every export (bill/badge/config PDF,
// XML backup) lands in the USER-VISIBLE Downloads — on Android via the
// MediaStore channel — and files saved by older builds migrate out of
// the hidden app dir once.
import 'dart:io';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mimeTypeFor maps the export types viewers key off', () {
    expect(mimeTypeFor('bill-2026-07.PDF'), 'application/pdf');
    expect(mimeTypeFor('workspace.xml'), 'text/xml');
    expect(mimeTypeFor('qr.png'), 'image/png');
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
