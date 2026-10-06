// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:io';

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

/// The device implementation: every export lands in the user's DOWNLOADS
/// — Android via the MediaStore channel, desktop/iOS via the Downloads
/// directory, falling back to app storage.
Future<String?> saveToDownloads({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (Platform.isAndroid) {
    try {
      final path = await _downloadsChannel.invokeMethod<String>('save', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeTypeFor(fileName),
      });
      if (path != null) return path;
    } catch (e, st) {
      // Channel missing (old binary) or MediaStore refusal — fall back to
      // the legacy app dir rather than losing the file.
      TraceLogger.instance.error('files', 'downloads save failed',
          error: e, stackTrace: st);
    }
  }
  Directory? dir;
  if (Platform.isAndroid) {
    dir = await getExternalStorageDirectory();
  }
  dir ??= await getDownloadsDirectory();
  dir ??= await getApplicationDocumentsDirectory();
  return writeFileAtomically(File('${dir.path}/$fileName'), bytes);
}

/// #1885 — a file appears whole or not at all: the bytes go to a sibling
/// temporary file, are flushed and size-checked, and only then take the
/// final name. A failure at any point removes the temporary file and leaves
/// what was there before (a previous valid export) untouched.
Future<String> writeFileAtomically(File target, List<int> bytes) async {
  final part = File('${target.path}.part');
  try {
    await part.writeAsBytes(bytes, flush: true);
    if (await part.length() != bytes.length) {
      throw FileSystemException('short write', part.path);
    }
    await part.rename(target.path);
    return target.path;
  } catch (e, st) {
    TraceLogger.instance
        .error('files', 'atomic write failed', error: e, stackTrace: st);
    try {
      if (part.existsSync()) await part.delete();
    } catch (e2, st2) {
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
}) async {
  Future<String> write(Directory dir) async {
    return writeFileAtomically(File('${dir.path}/$fileName'), bytes);
  }

  try {
    if (Platform.isAndroid) {
      try {
        final path = await _downloadsChannel.invokeMethod<String>('save', {
          'fileName': fileName,
          'bytes': bytes,
          'mimeType': mimeTypeFor(fileName),
        });
        if (path != null) return SavedFile(path);
      } catch (e, st) {
        TraceLogger.instance.error('files', 'downloads save failed',
            error: e, stackTrace: st);
      }
      final private = await getExternalStorageDirectory();
      if (private != null) return SavedPrivately(await write(private));
    } else if (!Platform.isIOS) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return SavedFile(await write(downloads));
    }
    return SavedPrivately(await write(await getApplicationDocumentsDirectory()));
  } catch (e, st) {
    TraceLogger.instance
        .error('files', 'typed save failed', error: e, stackTrace: st);
    return const SaveFailed();
  }
}

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
    } catch (e, st) {
      TraceLogger.instance.error('files', 'legacy export migration failed',
          error: e, stackTrace: st);
    }
  }
  return moved;
}
