// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../trace/trace_logger.dart';
import 'file_types.dart';

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
      SaveFailed() => null,
    };

/// #1885 — a file appears whole or not at all: the bytes go to a sibling
/// temporary file, are flushed and size-checked, and only then take the
/// final name. A failure at any point removes the temporary file and leaves
/// what was there before (a previous valid export) untouched.
@visibleForTesting
Future<String> writeFileAtomically(File target, List<int> bytes) async {
  final part = File('${target.path}.part');
  try {
    await part.writeAsBytes(bytes, flush: true);
    if (await part.length() != bytes.length) {
      throw FileSystemException('short write', part.path);
    }
    await part.rename(target.path);
    return target.path;
  } on Object catch (e, st) {
    TraceLogger.instance
        .error('files', 'atomic write failed', error: e, stackTrace: st);
    try {
      if (part.existsSync()) await part.delete();
    } on Object catch (e2, st2) {
      TraceLogger.instance.warn('files', 'temporary file not removed',
          error: e2, stackTrace: st2);
    }
    rethrow;
  }
}

/// #1872 — the same save, answering with what it achieved: a file the
/// person can find (MediaStore Downloads, a desktop Downloads folder),
/// or a copy only the app can see (the Android fallback, iOS app
/// documents, which this app does not share with Files), or a failure.
Future<SaveOutcome> saveToDownloadsTyped({
  required Uint8List bytes,
  required String fileName,
}) =>
    saveOn(_platform, _deviceTargets, bytes: bytes, fileName: fileName);

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
