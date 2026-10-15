// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2586 — why a report image could not be read, when the object is not
/// simply absent. `null` from `fetchReportImage` means ONLY "the optional
/// image is not there"; everything below is a failure that must not render
/// as a deleted image.
enum ReportImageFailureKind {
  /// The server refused the read (401/403): denied or the session expired.
  forbidden,

  /// The read did not complete: transport, timeout or a server fault.
  unavailable,

  /// Bytes arrived but are not a supported image.
  invalid,
}

/// A report image that exists (or may exist) but could not be used.
class ReportImageFailure implements Exception {
  const ReportImageFailure(this.kind, this.name, [this.cause, this.stackTrace]);

  final ReportImageFailureKind kind;

  /// The library name of the image.
  final String name;

  /// The underlying error, for the trace; never shown, never logged with
  /// image bytes.
  final Object? cause;

  /// The stack of [cause], for the trace.
  final StackTrace? stackTrace;

  @override
  String toString() => 'ReportImageFailure(${kind.name}: $name)';
}
