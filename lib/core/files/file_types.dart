// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/services.dart';

/// Writes [bytes] to a local file named [fileName] and returns a handle to
/// it (null on failure): a filesystem path on a device, the file name in a
/// browser, where "where it went" is the download folder the browser owns.
/// Deliberately a LOCAL save — the file lands in the user's own storage,
/// never handed to the system share sheet or another app.
typedef FileSaver = Future<String?> Function({
  required Uint8List bytes,
  required String fileName,
});

/// #1872 — what a save actually achieved, said truthfully. The plain
/// [FileSaver] answers with a string the UI cannot tell apart (a real
/// path, a browser's file name, an app-private fallback); this type
/// keeps them apart so no screen claims a file nobody can find.
sealed class SaveOutcome {
  const SaveOutcome();
}

/// The platform reported a user-visible file (Downloads, MediaStore).
final class SavedFile extends SaveOutcome {
  const SavedFile(this.path);
  final String path;
}

/// Kept, but only where the app can see it (the Android fallback when
/// MediaStore refused; iOS app documents, not shared with Files).
final class SavedPrivately extends SaveOutcome {
  const SavedPrivately(this.path);
  final String path;
}

/// A browser was handed the bytes. Where they land, and whether the
/// person kept them, the browser does not say.
final class DownloadRequested extends SaveOutcome {
  const DownloadRequested(this.fileName);
  final String fileName;
}

/// The save failed; nothing was written that the app knows of.
final class SaveFailed extends SaveOutcome {
  const SaveFailed();
}

/// A local save with a typed answer.
typedef TypedFileSaver = Future<SaveOutcome> Function({
  required Uint8List bytes,
  required String fileName,
});

/// MIME by extension for the Downloads entry (viewers key off it) — and,
/// on the web, for the Blob the browser is handed.
String mimeTypeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.xml')) return 'text/xml';
  // #864 — a report design travels as JSON. Without this it took the
  // octet-stream fallback, which also made migrateLegacyExports skip it.
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.png')) return 'image/png';
  // #1643 — a reservation's calendar file; the type is what makes a
  // browser or a phone offer the calendar rather than a text editor.
  if (lower.endsWith('.ics')) return 'text/calendar';
  if (lower.endsWith('.log') || lower.endsWith('.txt')) return 'text/plain';
  // #1872 — the task recorder's package and its rendered outputs.
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.vtt')) return 'text/vtt';
  if (lower.endsWith('.md')) return 'text/markdown';
  return 'application/octet-stream';
}
