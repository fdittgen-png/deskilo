// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3072 — a feature two subprocesses share is one thing to switch on: the
// "Switched off" note of a partial process names and counts it once.
import 'package:deskilo/features/workspace/application/process_status.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

SubprocessStatus _sub(String key, List<WorkspaceFeature> off) =>
    SubprocessStatus(
      subprocess: WorkspaceSubprocess(key, off),
      state: ProcessState.partial,
      enabled: const [],
      off: off,
      heldBack: const [],
    );

void main() {
  test('a shared off feature is listed once, in first-seen order', () {
    final status = ProcessStatus(
      process: workspaceProcesses.first,
      state: ProcessState.partial,
      subprocesses: [
        _sub('a', [WorkspaceFeature.coOwner, WorkspaceFeature.roleManagement]),
        _sub('b', [WorkspaceFeature.roleManagement, WorkspaceFeature.coOwner]),
      ],
      activeSubprocessCount: 0,
      outsidePrerequisites: const [],
    );
    expect(status.offFeatures, [
      WorkspaceFeature.coOwner,
      WorkspaceFeature.roleManagement,
    ]);
  });
}
