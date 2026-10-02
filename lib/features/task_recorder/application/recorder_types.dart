// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the values the recorder controller hands out: its scope, its
// status for the indicator, the operation token, and the small helpers
// it relies on.
part of 'recorder_controller.dart';

/// The account, workspace and installation a recording belongs to, as
/// one digest. Two accounts on two installations that happen to share a
/// workspace id are two scopes.
class RecorderScope {
  const RecorderScope._(this.digest);

  factory RecorderScope.of({
    required String backendUrl,
    required String userId,
    String? workspaceId,
  }) => RecorderScope._(
    cacheDigest('task-recorder-scope-v1', [
      backendUrl,
      userId,
      workspaceId ?? '',
    ], 32),
  );

  /// The account part alone: names the private store's namespace.
  static String accountNamespace({
    required String backendUrl,
    required String userId,
  }) => cacheDigest('task-recorder-account-v1', [backendUrl, userId], 32);

  final String digest;

  @override
  bool operator ==(Object other) =>
      other is RecorderScope && other.digest == digest;

  @override
  int get hashCode => digest.hashCode;
}

/// Where the recorder is in its lifecycle.
enum RecorderState { idle, recording, paused, ended }

/// A snapshot for the indicator and the controls.
class RecorderStatus {
  const RecorderStatus({
    required this.state,
    required this.epoch,
    required this.stepCount,
    this.endReason,
  });

  final RecorderState state;
  final int epoch;
  final int stepCount;
  final RecordingEndReason? endReason;
}

/// Links a command attempt to its outcome, within one recording.
class OperationToken {
  const OperationToken._(this.epoch, this.op, this.actionId);

  final int epoch;
  final String op;
  final String actionId;
}

/// A monotonic millisecond clock. Wall time never enters a recording.
typedef MonotonicMs = int Function();

MonotonicMs stopwatchClock() {
  final watch = Stopwatch()..start();
  return () => watch.elapsedMilliseconds;
}

final _random = Random.secure();

String _randomId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// Trims, refuses control characters, and caps the length. Null when
/// nothing is left. The text is the person's own; it is shown back to
/// them before any export and never claimed to be anonymous.
String? _cleanProse(String? text, int maxLength) {
  if (text == null) return null;
  final clean = text
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]'), ' ')
      .trim();
  if (clean.isEmpty) return null;
  return clean.length > maxLength ? clean.substring(0, maxLength) : clean;
}
