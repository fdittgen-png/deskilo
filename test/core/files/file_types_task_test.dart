// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the task recorder's files carry their real types (a viewer and
// a browser key off them), and the legacy-directory repair still moves
// only the kinds it was written for: a package, a document or a video in
// that directory is left where it is.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_saver_io.dart';
import 'package:deskilo/core/files/file_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package, document, video and caption types', () {
    expect(mimeTypeFor('a.deskilo-task.zip'), 'application/zip');
    expect(
      mimeTypeFor('a.DOCX'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(mimeTypeFor('a.mp4'), 'video/mp4');
    expect(mimeTypeFor('a.webm'), 'video/webm');
    expect(mimeTypeFor('a.vtt'), 'text/vtt');
    expect(mimeTypeFor('a.md'), 'text/markdown');
    expect(mimeTypeFor('a.bin'), 'application/octet-stream');
  });

  test('the legacy repair moves the old kinds only', () async {
    final dir = Directory.systemTemp.createTempSync('legacy');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final name in ['a.pdf', 'b.deskilo-task.zip', 'c.docx', 'd.mp4']) {
      File('${dir.path}/$name').writeAsBytesSync([1]);
    }
    final moved = <String>[];
    final n = await migrateLegacyExports(
      legacyDir: dir,
      save: ({required Uint8List bytes, required String fileName}) async {
        moved.add(fileName);
        return '/Downloads/$fileName';
      },
    );
    expect(n, 1);
    expect(moved, ['a.pdf']);
  });

  test('the typed outcomes tell a file, a private copy, a request and a failure apart', () {
    const outcomes = <SaveOutcome>[
      SavedFile('/Downloads/x'),
      SavedPrivately('/data/x'),
      DownloadRequested('x'),
      SaveFailed(),
    ];
    final kinds = outcomes
        .map(
          (o) => switch (o) {
            SavedFile() => 'file',
            SavedPrivately() => 'private',
            DownloadRequested() => 'requested',
            SaveFailed() => 'failed',
          },
        )
        .toList();
    expect(kinds, ['file', 'private', 'requested', 'failed']);
  });
}
