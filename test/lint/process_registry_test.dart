// SPDX-License-Identifier: 0BSD
// Every capability has one business home, or an explicit internal reason.
import 'dart:io';
import '../../tool/build_process_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';

void main() {
  test('generated catalogue matches registry and manifest', () {
    expect(File('docs/design/process-catalogue.md').readAsStringSync(),
        buildProcessCatalogue());
  });
  test('registry accounts for every feature deterministically', () {
    expect(validateProcessRegistry(workspaceProcesses), isEmpty);
    expect(validateProcessRegistry(workspaceProcesses),
        validateProcessRegistry(workspaceProcesses));
  });
  test('missing mapping names the feature and repair location', () {
    final errors = validateProcessRegistry(const []);
    expect(errors.join(), contains('calendarTab'));
    expect(errors.join(), contains('workspace_process.dart'));
  });
  test('duplicate membership and keys are rejected', () {
    expect(validateProcessRegistry([
      ...workspaceProcesses, workspaceProcesses.first,
    ]).join(), contains('duplicate'));
  });
  test('unmapped dependency identifies its dependent and missing parent', () {
    final broken = [
      for (final process in workspaceProcesses)
        WorkspaceProcess(process.key, [
          for (final subprocess in process.subprocesses)
            WorkspaceSubprocess(subprocess.key, [
              for (final feature in subprocess.capabilities)
                if (feature != WorkspaceFeature.moneyTab) feature,
            ]),
        ]),
    ];
    expect(validateProcessRegistry(broken).join(),
        contains('unmapped prerequisite moneyTab'));
  });
  test('empty groups are rejected', () {
    expect(validateProcessRegistry(const [WorkspaceProcess('empty', [])])
        .join(), contains('empty process'));
  });
  test('internal classification requires a reason', () {
    expect(validateProcessRegistry(workspaceProcesses,
      internal: {WorkspaceFeature.siteDocuments: ''}).join(),
      contains('siteDocuments: internal reason missing'));
  });
}
