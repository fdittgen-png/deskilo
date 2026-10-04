// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — on a native build the app, and the workbench in it, is already
// local: there is nothing to keep.

import 'offline_tool.dart';

OfflineTool platformOfflineTool() => const _NativeOfflineTool();

class _NativeOfflineTool implements OfflineTool {
  const _NativeOfflineTool();

  @override
  Future<OfflineToolState> state() async => OfflineToolState.notNeeded;

  @override
  Future<OfflineToolState> keep() async => OfflineToolState.notNeeded;

  @override
  Future<OfflineToolState> forget() async => OfflineToolState.notNeeded;
}
