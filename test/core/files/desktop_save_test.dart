// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3613 — a desktop save asks where. The dialog proposes the file's name in
// the folder used last time; a closed dialog writes and remembers nothing;
// the chosen file appears whole or not at all; the folder is remembered only
// after a delivered save. Phones and the web keep the saver they had.
import 'dart:io';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _bytes = Uint8List.fromList([37, 80, 68, 70]);

/// A save dialog that records what it was asked and answers [answer].
class _Dialog {
  _Dialog(this.answer);

  String? answer;
  Exception? refusal;
  final asked = <({String name, String? folder})>[];

  Future<String?> pick({
    required String suggestedName,
    String? initialDirectory,
  }) async {
    asked.add((name: suggestedName, folder: initialDirectory));
    if (refusal case final error?) throw error;
    return answer;
  }
}

void main() {
  late Directory root;
  late InMemorySaveFolderStore folders;

  setUp(() {
    root = Directory.systemTemp.createTempSync('deskilo-desktop-save');
    folders = InMemorySaveFolderStore();
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<SaveOutcome> save(
    _Dialog dialog, {
    Future<String> Function(File target, List<int> bytes)? write,
    TypedFileSaver? withoutDialog,
  }) => saveAtChosenPlace(
    pick: dialog.pick,
    folders: folders,
    bytes: _bytes,
    fileName: 'invoice.pdf',
    write: write ?? writeToChosenPlace,
    withoutDialog:
        withoutDialog ??
        ({required bytes, required fileName}) async =>
            fail('the dialog was there; the old saver is not used'),
  );

  group('the dialog', () {
    test('proposes the file name; a first save lets the dialog choose the '
        'folder', () async {
      final dialog = _Dialog(null);
      await save(dialog);
      expect(dialog.asked.single.name, 'invoice.pdf');
      expect(dialog.asked.single.folder, isNull);
    });

    test('starts in the folder of the last delivered save', () async {
      final first = Directory('${root.path}/exports')..createSync();
      final dialog = _Dialog('${first.path}/invoice.pdf');
      await save(dialog);
      await save(dialog);
      expect(dialog.asked.last.folder, first.path);
      expect(folders.folder, first.path);
    });

    test('a remembered folder that no longer exists is not proposed', () async {
      folders.folder = '${root.path}/gone';
      final dialog = _Dialog(null);
      await save(dialog);
      expect(dialog.asked.single.folder, isNull);
    });
  });

  group('the outcome', () {
    test('a delivered save is a file at the chosen place, written whole, and '
        'its folder is remembered', () async {
      final target = '${root.path}/invoice-2026.pdf';
      final outcome = await save(_Dialog(target));
      expect(
        outcome,
        isA<SavedFile>()
            .having((o) => o.path, 'path', target)
            .having((o) => o.atChosenPlace, 'atChosenPlace', isTrue),
      );
      expect(File(target).readAsBytesSync(), _bytes);
      expect(folders.folder, root.path);
      expect(folders.writes, 1);
    });

    test('a closed dialog is a cancellation: nothing written, nothing '
        'remembered', () async {
      folders.folder = root.path;
      final outcome = await save(_Dialog(null));
      expect(outcome, isA<SaveCancelled>());
      expect(root.listSync(), isEmpty);
      expect(folders.writes, 0);
      expect(folders.folder, root.path);
    });

    test('a refused write is a failure with its reason; the folder is not '
        'remembered', () async {
      final missing = '${root.path}/not-created/invoice.pdf';
      final outcome = await save(_Dialog(missing));
      expect(
        outcome,
        isA<SaveFailed>().having(
          (o) => o.reason,
          'reason',
          SaveFailure.chosenFolderRefused,
        ),
      );
      expect(root.listSync(), isEmpty);
      expect(folders.writes, 0);
    });

    test('a write that stops half-way leaves no file and no temporary file '
        'at the destination', () async {
      final target = '${root.path}/invoice.pdf';
      final outcome = await save(
        _Dialog(target),
        write: (file, bytes) => writeFileAtomically(
          file,
          bytes,
          beforeRename: (part) async {
            expect(part.existsSync(), isTrue, reason: 'the bytes were written');
            throw const FileSystemException('disk unplugged');
          },
        ),
      );
      expect(outcome, isA<SaveFailed>());
      expect(root.listSync(), isEmpty, reason: 'no file and no .part remain');
      expect(folders.writes, 0);
    });

    test(
      'a half-way failure leaves an earlier file at the place untouched',
      () async {
        final target = File('${root.path}/invoice.pdf')
          ..writeAsBytesSync([1, 2]);
        await save(
          _Dialog(target.path),
          write: (file, bytes) => writeFileAtomically(
            file,
            bytes,
            beforeRename: (_) async => throw const FileSystemException('stop'),
          ),
        );
        expect(target.readAsBytesSync(), [1, 2]);
        expect(root.listSync(), hasLength(1));
      },
    );

    test(
      'a desktop that cannot show the dialog saves the way it did before',
      () async {
        final dialog = _Dialog(null)
          ..refusal = PlatformException(code: 'no_portal');
        var before = 0;
        final outcome = await save(
          dialog,
          withoutDialog: ({required bytes, required fileName}) async {
            before++;
            return const SavedFile('/home/me/Downloads/invoice.pdf');
          },
        );
        expect(before, 1);
        expect(
          outcome,
          isA<SavedFile>().having((o) => o.atChosenPlace, 'chosen', isFalse),
        );
      },
    );
  });

  group('only the chosen file is granted (a sandboxed macOS build)', () {
    /// The first way, with the temporary file beside the target refused at
    /// creation, as the sandbox refuses it.
    Future<String> siblingRefused(File target, List<int> bytes) =>
        writeFileAtomically(
          target,
          bytes,
          openPart: (part) async =>
              throw FileSystemException('Operation not permitted', part.path),
        );

    test(
      'the file is written whole at the chosen path, and delivered',
      () async {
        final target = '${root.path}/invoice.pdf';
        final outcome = await save(
          _Dialog(target),
          write: (file, bytes) =>
              writeToChosenPlace(file, bytes, atomic: siblingRefused),
        );
        expect(
          outcome,
          isA<SavedFile>()
              .having((o) => o.path, 'path', target)
              .having((o) => o.atChosenPlace, 'atChosenPlace', isTrue),
        );
        expect(File(target).readAsBytesSync(), _bytes);
        expect(root.listSync(), hasLength(1), reason: 'no .part file');
        expect(folders.folder, root.path);
      },
    );

    test('a direct write that fails half-way leaves nothing at the chosen '
        'path, and the outcome is failed', () async {
      final target = '${root.path}/invoice.pdf';
      final outcome = await save(
        _Dialog(target),
        write: (file, bytes) => writeToChosenPlace(
          file,
          bytes,
          atomic: siblingRefused,
          direct: (file, bytes) async {
            file.writeAsBytesSync(bytes.sublist(0, 2));
            throw FileSystemException('disk full', file.path);
          },
        ),
      );
      expect(
        outcome,
        isA<SaveFailed>().having(
          (o) => o.reason,
          'reason',
          SaveFailure.chosenFolderRefused,
        ),
      );
      expect(root.listSync(), isEmpty, reason: 'nothing at the chosen path');
      expect(folders.writes, 0);
    });

    test('a direct write that fails half-way over a file the person chose to '
        'replace gives that file back, whole', () async {
      // The dialog let the person pick an existing file; the direct write
      // truncates it at once, so a failure must not cost them the original.
      final target = '${root.path}/invoice.pdf';
      const original = [9, 8, 7, 6, 5, 4, 3];
      File(target).writeAsBytesSync(original);
      final outcome = await save(
        _Dialog(target),
        write: (file, bytes) => writeToChosenPlace(
          file,
          bytes,
          atomic: siblingRefused,
          direct: (file, bytes) async {
            file.writeAsBytesSync(bytes.sublist(0, 2));
            throw FileSystemException('disk full', file.path);
          },
        ),
      );
      expect(outcome, isA<SaveFailed>());
      expect(File(target).readAsBytesSync(), original);
      expect(root.listSync(), hasLength(1), reason: 'the original only');
      expect(folders.writes, 0);
    });

    test('a file to replace that cannot be read is not written over', () async {
      // Without its bytes the original could not be given back, so the
      // direct write is not attempted and the original is left as it is.
      final target = '${root.path}/invoice.pdf';
      const original = [9, 8, 7];
      File(target).writeAsBytesSync(original);
      var direct = 0;
      final outcome = await save(
        _Dialog(target),
        write: (file, bytes) => writeToChosenPlace(
          file,
          bytes,
          atomic: siblingRefused,
          direct: (file, bytes) async => direct++,
          existing: (file) async =>
              throw FileSystemException('Permission denied', file.path),
        ),
      );
      expect(outcome, isA<SaveFailed>());
      expect(direct, 0);
      expect(File(target).readAsBytesSync(), original);
    });

    test('where the folder allows it, the first way is used and the direct '
        'write is not', () async {
      final target = '${root.path}/invoice.pdf';
      var direct = 0;
      final outcome = await save(
        _Dialog(target),
        write: (file, bytes) => writeToChosenPlace(
          file,
          bytes,
          direct: (file, bytes) async => direct++,
        ),
      );
      expect(outcome, isA<SavedFile>());
      expect(direct, 0);
      expect(File(target).readAsBytesSync(), _bytes);
      expect(root.listSync(), hasLength(1));
    });

    test('a failure after the temporary file was made is not a refusal: no '
        'direct write, nothing left', () async {
      final target = '${root.path}/invoice.pdf';
      var direct = 0;
      final outcome = await save(
        _Dialog(target),
        write: (file, bytes) => writeToChosenPlace(
          file,
          bytes,
          atomic: (file, bytes) => writeFileAtomically(
            file,
            bytes,
            beforeRename: (_) async =>
                throw const FileSystemException('rename refused'),
          ),
          direct: (file, bytes) async => direct++,
        ),
      );
      expect(outcome, isA<SaveFailed>());
      expect(direct, 0);
      expect(root.listSync(), isEmpty);
    });
  });

  group('phones and the web keep their saver', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('${platform.name}: the typed saver is the one it always was', () {
        debugDefaultTargetPlatformOverride = platform;
        expect(typedSaverFor(folders), same(saveToDownloadsTyped));
        final container = ProviderContainer(
          overrides: [saveFolderStoreProvider.overrideWithValue(folders)],
        );
        addTearDown(container.dispose);
        expect(
          container.read(typedFileSaverProvider),
          same(saveToDownloadsTyped),
        );
      });
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('${platform.name}: the typed saver asks where', () {
        debugDefaultTargetPlatformOverride = platform;
        expect(typedSaverFor(folders), isNot(same(saveToDownloadsTyped)));
      });
    }

    test('the browser answers with its download request, as before', () {
      // The web implementation cannot run on this host; its source is the
      // proof that no dialog and no folder reach a browser save.
      final web = File('lib/core/files/file_saver_web.dart').readAsStringSync();
      expect(
        web,
        contains(
          'TypedFileSaver typedSaverFor(SaveFolderStore _) => '
          'saveToDownloadsTyped;',
        ),
      );
      expect(web, isNot(contains('getSaveLocation')));
    });

    test(
      'the legacy string seam never asks: it keeps writing where it did',
      () {
        final io = File('lib/core/files/file_saver_io.dart').readAsStringSync();
        final legacy = io.substring(
          io.indexOf('Future<String?> saveToDownloads('),
          io.indexOf('/// #1885'),
        );
        expect(legacy, contains('saveToDownloadsTyped('));
        expect(legacy, isNot(contains('saveAtChosenPlace')));
      },
    );
  });
}
