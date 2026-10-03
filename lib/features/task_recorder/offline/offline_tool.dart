// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — "Keep the workbench on this device": the installable, offline
// local tool is the web build itself, with a service worker the person
// switches on from the workbench (web/task_tool_sw.js). Nothing is
// switched on by default; on a native build the app is already local and
// this answers "not needed here".

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'offline_tool_io.dart'
    if (dart.library.js_interop) 'offline_tool_web.dart'
    as impl;

part 'offline_tool.g.dart';

/// Where keeping the workbench offline stands on this device.
enum OfflineToolState {
  /// Not a browser: the app on this device is already local.
  notNeeded,

  /// A browser without service workers (or a private window): offline
  /// use is not possible here.
  unsupported,

  /// Kept: the screens already opened work without a connection.
  ready,

  /// Not kept (never asked, or stopped).
  off,

  /// The browser refused.
  failed,
}

/// Turns the offline copy on or off, and says where it stands.
abstract interface class OfflineTool {
  Future<OfflineToolState> state();
  Future<OfflineToolState> keep();
  Future<OfflineToolState> forget();
}

@Riverpod(keepAlive: true)
OfflineTool offlineTool(Ref ref) => impl.platformOfflineTool();
