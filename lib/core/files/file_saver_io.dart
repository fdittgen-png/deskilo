// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';

import 'package:file_selector/file_selector.dart' show getSaveLocation;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../trace/trace_logger.dart';
import 'file_types.dart';
import 'save_folder_store.dart';

/// Android MediaStore bridge (MainActivity.kt): saves into the
/// USER-VISIBLE Downloads collection — the app-private external dir is
/// hidden from on-device file managers (field report).
const _downloadsChannel = MethodChannel('deskilo/downloads');

/// The export types the legacy-directory repair moves.
const _legacyExportTypes = {
  'application/pdf',
  'text/xml',
  'application/json',
  'image/png',
  'text/calendar',
  'text/plain',
};

/// The kinds of device a local save decides between. The web never gets
/// here: its own implementation hands the bytes to the browser.
@visibleForTesting
enum SavePlatform {
  /// MediaStore's Downloads first, the app-private external dir when it
  /// refuses.
  android,

  /// The sandbox only: an iPhone's app documents are not Files, so a save
  /// here is never reported as a folder the person can open.
  ios,

  /// A desktop's Downloads folder, the app documents when it has none.
  desktop,
}

/// Where a device save can go, each supplied by the platform — or by a test,
/// which is how the decision per platform is proved on a host that is none
/// of them.
@visibleForTesting
class SaveTargets {
  const SaveTargets({
    required this.mediaStore,
    required this.privateDir,
    required this.downloadsDir,
    required this.documentsDir,
  });

  /// Android's user-visible Downloads collection: answers the entry's
  /// path, or throws when MediaStore refuses the file.
  final Future<String?> Function(Uint8List bytes, String fileName) mediaStore;

  /// The app-private external directory (Android), null on a device that
  /// has none.
  final Future<Directory?> Function() privateDir;

  /// A desktop's Downloads folder, null on a platform without one.
  final Future<Directory?> Function() downloadsDir;

  /// The app's own documents directory.
  final Future<Directory> Function() documentsDir;
}

final _deviceTargets = SaveTargets(
  mediaStore: (bytes, fileName) => _downloadsChannel.invokeMethod<String>(
    'save',
    {
      'fileName': fileName,
      'bytes': bytes,
      'mimeType': mimeTypeFor(fileName),
    },
  ),
  privateDir: getExternalStorageDirectory,
  downloadsDir: getDownloadsDirectory,
  documentsDir: getApplicationDocumentsDirectory,
);

SavePlatform get _platform => Platform.isAndroid
    ? SavePlatform.android
    : Platform.isIOS
        ? SavePlatform.ios
        : SavePlatform.desktop;

/// An iPhone's sandbox is not Files: "download" there means choosing
/// between a private copy and the system sheet. Everywhere else the local
/// save lands where the person looks for downloads.
FileDeliveryMode get localSaveMode =>
    Platform.isIOS ? FileDeliveryMode.exportChooser : FileDeliveryMode.direct;

/// The device implementation of the legacy seam: the typed save's handle,
/// or null when nothing was written. The string cannot say which kind of
/// handle it is; [saveToDownloadsTyped] can.
Future<String?> saveToDownloads({
  required Uint8List bytes,
  required String fileName,
}) async =>
    switch (await saveToDownloadsTyped(bytes: bytes, fileName: fileName)) {
      SavedFile(:final path) || SavedPrivately(:final path) => path,
      DownloadRequested(:final fileName) => fileName,
      // The legacy string cannot say "cancelled"; this seam never asks,
      // so it never sees one. Mapped here, at its boundary, and nowhere
      // else.
      SaveCancelled() || SaveFailed() => null,
    };

/// #1885 — a file appears whole or not at all: the bytes go to a sibling
/// temporary file, are flushed and size-checked, and only then take the
/// final name. A failure at any point removes the temporary file and leaves
/// what was there before (a previous valid export) untouched.
///
/// [beforeRename] runs between the write and the rename; a test injects a
/// failure there to prove a write that stops half-way leaves nothing.
/// [openPart] opens the temporary file; a test injects a refusal there. A
/// refusal to create or open it is thrown as `_TemporaryFileRefused`, so
/// [writeToChosenPlace] can tell "no file may be made beside the target"
/// from a failed write.
@visibleForTesting
Future<String> writeFileAtomically(
  File target,
  List<int> bytes, {
  Future<void> Function(File part)? beforeRename,
  Future<RandomAccessFile> Function(File part) openPart = _openForWrite,
}) async {
  final part = File('${target.path}.part');
  final RandomAccessFile handle;
  try {
    handle = await openPart(part);
  } on FileSystemException catch (e, st) {
    TraceLogger.instance
        .warn('files', 'temporary file refused', error: e, stackTrace: st);
    await _discard(part);
    throw _TemporaryFileRefused(e);
  }
  try {
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await part.length() != bytes.length) {
      throw FileSystemException('short write', part.path);
    }
    if (beforeRename != null) await beforeRename(part);
    await part.rename(target.path);
    return target.path;
  } on Object catch (e, st) {
    TraceLogger.instance
        .error('files', 'atomic write failed', error: e, stackTrace: st);
    await _discard(part);
    rethrow;
  }
}

Future<RandomAccessFile> _openForWrite(File part) =>
    part.open(mode: FileMode.write);

/// Removes [file] when it exists; a removal that fails is traced, never
/// thrown over the failure being reported.
Future<void> _discard(File file) async {
  try {
    if (file.existsSync()) await file.delete();
  } on Object catch (e, st) {
    TraceLogger.instance
        .warn('files', 'file not removed', error: e, stackTrace: st);
  }
}

/// #3613 — the temporary file beside a target could not be created or
/// opened: nothing was written anywhere. It stays the file-system exception
/// it wraps, so every caller of [writeFileAtomically] that catches an
/// `IOException` or a `FileSystemException` sees what it saw before.
class _TemporaryFileRefused extends FileSystemException {
  _TemporaryFileRefused(FileSystemException cause)
    : super(cause.message, cause.path, cause.osError);
}

/// #3613 — writes [bytes] to the place a desktop person chose. The first way
/// is [writeFileAtomically]: a temporary file beside it, then a rename.
///
/// The second way exists for a sandboxed macOS build, where the save dialog
/// grants the chosen file and not its folder, so no temporary file may be
/// made beside it: the complete bytes are written to the chosen path itself
/// in one write with flush ([direct]). That way is NOT atomic, so a file the
/// person chose to replace is kept in memory first: when the write fails
/// part-way, its bytes are written back; a target that did not exist before
/// is deleted (the chosen path is granted). Then the failure is rethrown.
/// Neither way leaves a temporary file behind.
@visibleForTesting
Future<String> writeToChosenPlace(
  File target,
  List<int> bytes, {
  Future<String> Function(File target, List<int> bytes) atomic =
      writeFileAtomically,
  Future<void> Function(File target, List<int> bytes) direct = _writeDirect,
  Future<List<int>?> Function(File target) existing = _existingBytes,
}) async {
  try {
    return await atomic(target, bytes);
  } on _TemporaryFileRefused {
    // What the person is replacing, if anything: the direct write truncates
    // it at once, so it is read before a byte is written.
    final List<int>? before;
    try {
      before = await existing(target);
    } on FileSystemException catch (e, st) {
      // A file that is there and cannot be read cannot be given back:
      // nothing is written, so nothing is truncated.
      TraceLogger.instance
          .warn('files', 'file to replace not read', error: e, stackTrace: st);
      rethrow;
    }
    try {
      await direct(target, bytes);
      return target.path;
    } on Object catch (e, st) {
      TraceLogger.instance
          .error('files', 'direct write failed', error: e, stackTrace: st);
      await _restore(target, before);
      rethrow;
    }
  }
}

/// After a failed direct write: [before] is written back when the target
/// existed, else what was written is removed. A failure here is traced,
/// never thrown over the failure being reported.
Future<void> _restore(File target, List<int>? before) async {
  if (before == null) return _discard(target);
  try {
    await target.writeAsBytes(before, flush: true);
    TraceLogger.instance.warn('files', 'replaced file given back');
  } on Object catch (e, st) {
    TraceLogger.instance
        .error('files', 'replaced file not given back', error: e, stackTrace: st);
  }
}

/// The bytes of the file at [target], or null when there is none; a file
/// that is there and cannot be read throws.
Future<List<int>?> _existingBytes(File target) async =>
    target.existsSync() ? await target.readAsBytes() : null;

Future<void> _writeDirect(File target, List<int> bytes) =>
    target.writeAsBytes(bytes, flush: true);

/// #1872 — the same save, answering with what it achieved: a file the
/// person can find (MediaStore Downloads, a desktop Downloads folder),
/// or a copy only the app can see (the Android fallback, iOS app
/// documents, which this app does not share with Files), or a failure.
Future<SaveOutcome> saveToDownloadsTyped({
  required Uint8List bytes,
  required String fileName,
}) =>
    saveOn(_platform, _deviceTargets, bytes: bytes, fileName: fileName);

/// #3613 — the typed saver of this device. A desktop (Windows, macOS,
/// Linux) asks where the file goes, starting from the folder remembered in
/// [folders]; a phone keeps [saveToDownloadsTyped] exactly as before.
/// `defaultTargetPlatform`, not `dart:io`: widget tests run as Android.
TypedFileSaver typedSaverFor(SaveFolderStore folders) =>
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux =>
        ({required bytes, required fileName}) => saveAtChosenPlace(
          pick: _pickWithFileSelector,
          folders: folders,
          bytes: bytes,
          fileName: fileName,
        ),
      _ => saveToDownloadsTyped,
    };

/// Asks where [suggestedName] goes, starting in [initialDirectory]; null
/// when the person closed the dialog.
typedef SaveLocationPicker = Future<String?> Function({
  required String suggestedName,
  String? initialDirectory,
});

Future<String?> _pickWithFileSelector({
  required String suggestedName,
  String? initialDirectory,
}) async =>
    (await getSaveLocation(
      suggestedName: suggestedName,
      initialDirectory: initialDirectory,
    ))
        ?.path;

/// #3613 — a desktop save: the dialog proposes [fileName] in the folder
/// used last time; a closed dialog is [SaveCancelled] and writes and
/// remembers nothing; the chosen file is written atomically and its folder
/// remembered only once the write is acknowledged. A desktop that cannot
/// show the dialog at all saves the way it did before ([withoutDialog]).
@visibleForTesting
Future<SaveOutcome> saveAtChosenPlace({
  required SaveLocationPicker pick,
  required SaveFolderStore folders,
  required Uint8List bytes,
  required String fileName,
  Future<String> Function(File target, List<int> bytes) write =
      writeToChosenPlace,
  TypedFileSaver withoutDialog = saveToDownloadsTyped,
}) async {
  final String? chosen;
  try {
    chosen = await pick(
      suggestedName: fileName,
      initialDirectory: await _lastFolder(folders),
    );
  } on Object catch (e, st) {
    TraceLogger.instance
        .warn('files', 'no save dialog here', error: e, stackTrace: st);
    return withoutDialog(bytes: bytes, fileName: fileName);
  }
  if (chosen == null) return const SaveCancelled();
  final target = File(chosen);
  try {
    final path = await write(target, bytes);
    await _remember(folders, target.parent.path);
    return SavedFile(path, atChosenPlace: true);
  } on Object catch (e, st) {
    TraceLogger.instance
        .error('files', 'chosen place refused', error: e, stackTrace: st);
    return const SaveFailed(SaveFailure.chosenFolderRefused);
  }
}

/// The remembered folder while it still exists; a removed or unreadable
/// one lets the dialog choose its own start.
Future<String?> _lastFolder(SaveFolderStore folders) async {
  try {
    final folder = await folders.read();
    return folder != null && Directory(folder).existsSync() ? folder : null;
  } on Object catch (e, st) {
    TraceLogger.instance
        .warn('files', 'last folder unreadable', error: e, stackTrace: st);
    return null;
  }
}

/// Remembering is a convenience: a store that refuses does not undo a
/// file that was written.
Future<void> _remember(SaveFolderStore folders, String folder) async {
  try {
    await folders.write(folder);
  } on Object catch (e, st) {
    TraceLogger.instance
        .warn('files', 'last folder not kept', error: e, stackTrace: st);
  }
}

/// The decision per platform, over [targets]. Never throws: a refused
/// folder or write is a [SaveFailed] with its reason, and nothing
/// half-written remains.
@visibleForTesting
Future<SaveOutcome> saveOn(
  SavePlatform platform,
  SaveTargets targets, {
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    return switch (platform) {
      SavePlatform.android => await _saveOnAndroid(targets, bytes, fileName),
      SavePlatform.ios =>
        await _savePrivately(targets.documentsDir, null, bytes, fileName),
      SavePlatform.desktop => await _saveOnDesktop(targets, bytes, fileName),
    };
  } on Object catch (e, st) {
    TraceLogger.instance
        .error('files', 'typed save failed', error: e, stackTrace: st);
    return const SaveFailed(SaveFailure.writeFailed);
  }
}

Future<SaveOutcome> _saveOnAndroid(
  SaveTargets targets,
  Uint8List bytes,
  String fileName,
) async {
  try {
    final path = await targets.mediaStore(bytes, fileName);
    if (path != null) return SavedFile(path);
  } on Object catch (e, st) {
    // Channel missing (old binary) or MediaStore refusal — the private
    // copy below is the honest fallback, and is reported as such.
    TraceLogger.instance.error('files', 'downloads save failed',
        error: e, stackTrace: st);
  }
  return _savePrivately(
      targets.privateDir, targets.documentsDir, bytes, fileName);
}

Future<SaveOutcome> _saveOnDesktop(
  SaveTargets targets,
  Uint8List bytes,
  String fileName,
) async {
  final downloads = await _directoryOrNull(targets.downloadsDir);
  if (downloads != null) {
    return SavedFile(await _write(downloads, fileName, bytes));
  }
  return _savePrivately(targets.documentsDir, null, bytes, fileName);
}

/// A copy only the app can see, in [first] or else in [second]; with no
/// folder at all the failure says so instead of inventing a path.
Future<SaveOutcome> _savePrivately(
  Future<Directory?> Function() first,
  Future<Directory?> Function()? second,
  Uint8List bytes,
  String fileName,
) async {
  final dir = await _directoryOrNull(first) ??
      (second == null ? null : await _directoryOrNull(second));
  if (dir == null) return const SaveFailed(SaveFailure.noStorage);
  return SavedPrivately(await _write(dir, fileName, bytes));
}

Future<Directory?> _directoryOrNull(
  Future<Directory?> Function() lookup,
) async {
  try {
    return await lookup();
  } on Object catch (e, st) {
    TraceLogger.instance
        .warn('files', 'no such directory here', error: e, stackTrace: st);
    return null;
  }
}

Future<String> _write(Directory dir, String fileName, Uint8List bytes) =>
    writeFileAtomically(File('${dir.path}/$fileName'), bytes);

/// One-time repair (field report): files saved before the Downloads
/// bridge sit in the app-private external dir, invisible to on-device
/// file managers. Moves every export there (*.pdf, *.xml, *.png, *.log)
/// into Downloads and deletes the hidden original on success.
///
/// [legacyDir]/[save] are injectable for tests; production uses the real
/// dir and [saveToDownloads].
Future<int> migrateLegacyExports({
  Directory? legacyDir,
  FileSaver? save,
}) async {
  if (legacyDir == null && !Platform.isAndroid) return 0;
  final dir = legacyDir ?? await getExternalStorageDirectory();
  if (dir == null || !dir.existsSync()) return 0;
  final saver = save ?? saveToDownloads;
  var moved = 0;
  for (final entry in dir.listSync()) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.last;
    // #1872 — only the kinds this repair was written for; a newer
    // export type never lived in the legacy directory.
    if (!_legacyExportTypes.contains(mimeTypeFor(name))) continue;
    try {
      final path = await saver(
        bytes: await entry.readAsBytes(),
        fileName: name,
      );
      // Only delete the hidden original once the visible copy exists —
      // and never when the fallback wrote back into the same directory.
      if (path != null && !path.startsWith(dir.path)) {
        await entry.delete();
        moved++;
      }
    } on Object catch (e, st) {
      TraceLogger.instance.error('files', 'legacy export migration failed',
          error: e, stackTrace: st);
    }
  }
  return moved;
}
