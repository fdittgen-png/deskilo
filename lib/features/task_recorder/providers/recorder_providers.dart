// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — how the app holds its one task recorder.
//
// The controller lives for the whole run (keepAlive) and is created
// lazily, the first time the recorder screen asks for it. Nothing on the
// start-up path reads it: the indicator only listens to its status once
// it exists, so the first frame never waits on the recorder (#2033).
//
// The scope a recording belongs to is the installation, the signed-in
// account and the active workspace, as one digest. When any of them
// changes, the live recording ends before anything of the new scope can
// enter it.

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/time/clock.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/recorder_controller.dart';
import '../data/recorder_log_backends.dart';
import '../data/recorder_store.dart';
import '../domain/recording_sink.dart';
import '../domain/task_recording.dart';

part 'recorder_providers.g.dart';

/// Where recordings are kept on this device: a file per recording, or
/// the browser's own storage.
@Riverpod(keepAlive: true)
RecorderLogBackend recorderLogBackend(Ref ref) =>
    kIsWeb ? PrefsRecorderLogBackend() : FileRecorderLogBackend();

/// The signed-in account's private recordings; null when signed out.
@riverpod
RecorderStore? recorderStore(Ref ref) {
  final account = ref.watch(currentAccountIdProvider);
  if (account == null || account.isEmpty) return null;
  return RecorderStore(
    backend: ref.watch(recorderLogBackendProvider),
    namespace: RecorderScope.accountNamespace(
        backendUrl: ref.watch(bootedBackendUrlProvider), userId: account),
    clock: ref.watch(clockProvider),
  );
}

/// The scope a new recording would belong to; null when signed out.
@riverpod
RecorderScope? recorderScope(Ref ref) {
  final account = ref.watch(currentAccountIdProvider);
  if (account == null || account.isEmpty) return null;
  return RecorderScope.of(
    backendUrl: ref.watch(bootedBackendUrlProvider),
    userId: account,
    workspaceId: ref.watch(activeWorkspaceIdProvider).value,
  );
}

/// Whether this workspace lets its people record a task here.
@riverpod
bool taskRecorderAvailable(Ref ref) => ref
    .watch(enabledFeaturesSyncProvider)
    .contains(WorkspaceFeature.taskRecorder);

/// The platform family a recording names. Never a device model.
RecordingPlatform currentRecordingPlatform() {
  if (kIsWeb) return RecordingPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => RecordingPlatform.android,
    TargetPlatform.iOS => RecordingPlatform.ios,
    TargetPlatform.macOS => RecordingPlatform.macos,
    TargetPlatform.windows => RecordingPlatform.windows,
    TargetPlatform.linux => RecordingPlatform.linux,
    TargetPlatform.fuchsia => RecordingPlatform.unknown,
  };
}

/// The one recorder of this run.
@Riverpod(keepAlive: true)
RecorderController recorderController(Ref ref) {
  final controller = RecorderController(
    sink: _AccountSink(() => ref.read(recorderStoreProvider)),
    platform: currentRecordingPlatform(),
  );
  ref
    ..listen(recorderScopeProvider, (_, next) => controller.scopeChanged(next))
    ..onDispose(controller.dispose);
  return controller;
}

/// The recorder's status, for the indicator and the controls.
@Riverpod(keepAlive: true)
Stream<RecorderStatus> recorderStatus(Ref ref) async* {
  final controller = ref.watch(recorderControllerProvider);
  // The current status first: a listener that arrives mid-recording
  // must not wait for the next step to know.
  yield controller.status;
  yield* controller.changes;
}

/// This account's recordings on this device, newest first.
@riverpod
Future<List<StoredRecording>> myRecordings(Ref ref) async {
  final store = ref.watch(recorderStoreProvider);
  if (store == null) return const <StoredRecording>[];
  await store.purgeExpired();
  return store.list();
}

/// Opens recordings in whichever account is signed in when Start is
/// pressed — never one chosen earlier.
class _AccountSink implements RecordingSink {
  _AccountSink(this._store);

  final RecorderStore? Function() _store;

  @override
  Future<RecordingWriter> begin(RecordingHeader header) {
    final store = _store();
    if (store == null) throw StateError('no account to record in');
    return store.begin(header);
  }
}

/// Whether the recorder was opened in this run. Until it was, the
/// indicator renders its child and nothing else, and reads nothing.
@Riverpod(keepAlive: true)
class RecorderOpened extends _$RecorderOpened {
  @override
  bool build() => false;

  void open() => state = true;
}
