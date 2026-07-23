// SPDX-License-Identifier: 0BSD
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../trace/trace_logger.dart';

part 'file_saver.g.dart';

/// Writes [bytes] to a local file named [fileName] on the device and returns
/// its full path (null on failure). Deliberately a LOCAL save — the file
/// lands in the device's own storage, never handed to the system share sheet
/// or another app.
typedef FileSaver = Future<String?> Function({
  required Uint8List bytes,
  required String fileName,
});

/// Android MediaStore bridge (MainActivity.kt): saves into the
/// USER-VISIBLE Downloads collection — the app-private external dir is
/// hidden from on-device file managers (field report).
const _downloadsChannel = MethodChannel('deskilo/downloads');

/// MIME by extension for the Downloads entry (viewers key off it).
String mimeTypeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.xml')) return 'text/xml';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.log') || lower.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem. Every export
/// lands in the user's DOWNLOADS: Android via the MediaStore channel,
/// desktop/iOS via the Downloads directory, falling back to app storage.
@Riverpod(keepAlive: true)
FileSaver fileSaver(Ref ref) => saveToDownloads;

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
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
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
    if (mimeTypeFor(name) == 'application/octet-stream') continue;
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
