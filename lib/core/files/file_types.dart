// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/services.dart';

/// Writes [bytes] to a local file named [fileName] and returns a handle to
/// it (null on failure): a filesystem path on a device, the file name in a
/// browser, where "where it went" is the download folder the browser owns.
/// Deliberately a LOCAL save — the file lands in the user's own storage,
/// never handed to the system share sheet or another app.
///
/// The legacy seam: its string cannot tell a file the person can find from
/// an app-private copy or a browser's request, so a screen reading it can
/// only say "Saved to" and hope. New code delivers through `deliverFile`
/// (file_delivery.dart) and announces the typed outcome; the hand-written
/// files still reading this seam only shrink
/// (test/lint/file_delivery_outcome_test.dart).
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

/// Why a delivery failed — the part of the answer the person can act on
/// (free space, another destination) beside what the trace keeps.
enum SaveFailure {
  /// No folder on the device would take the file: neither the platform's
  /// visible one nor the app's own.
  noStorage,

  /// A folder was found and the write itself was refused; nothing
  /// half-written remains (the atomic write cleans up after itself).
  writeFailed,

  /// The system share sheet could not be opened, so the bytes never left
  /// the app.
  shareUnavailable,

  /// The seam could not say more than "not saved".
  unknown,
}

/// The save failed; nothing was written that the app knows of.
final class SaveFailed extends SaveOutcome {
  const SaveFailed([this.reason = SaveFailure.unknown]);
  final SaveFailure reason;
}

/// A local save with a typed answer.
typedef TypedFileSaver = Future<SaveOutcome> Function({
  required Uint8List bytes,
  required String fileName,
});

/// How a "download" reaches the person on this platform.
enum FileDeliveryMode {
  /// The bytes go straight to the local saver: Downloads (Android, a
  /// desktop) or the browser's own download.
  direct,

  /// An iPhone: the app's sandbox is not Files, so the person chooses —
  /// keep a private copy inside the app, or hand the bytes to the system
  /// sheet (Save to Files when it is offered, Mail, AirDrop, another app).
  exportChooser,
}

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
