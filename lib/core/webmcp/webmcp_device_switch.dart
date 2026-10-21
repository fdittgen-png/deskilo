// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the per-device switch that lets an in-browser assistant use the
// open page's tools. Off by default and stored on this device only, never
// on the server: a restart, another device or an administrator cannot turn
// it on; only the person can, here.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'webmcp_device_switch.g.dart';

abstract class WebMcpSwitchStore {
  Future<bool> read();
  Future<void> write({required bool on});
}

class _PrefsWebMcpSwitchStore implements WebMcpSwitchStore {
  const _PrefsWebMcpSwitchStore();

  static const _key = 'webmcp_device_switch_on';

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> write({required bool on}) async =>
      (await SharedPreferences.getInstance()).setBool(_key, on);
}

@Riverpod(keepAlive: true)
WebMcpSwitchStore webMcpSwitchStore(Ref ref) => const _PrefsWebMcpSwitchStore();

/// True when the person let in-browser assistants use this page's tools on
/// this device.
@Riverpod(keepAlive: true)
class WebMcpDeviceSwitch extends _$WebMcpDeviceSwitch {
  @override
  Future<bool> build() => ref.watch(webMcpSwitchStoreProvider).read();

  Future<void> set({required bool on}) async {
    await ref.read(webMcpSwitchStoreProvider).write(on: on);
    state = AsyncData(on);
  }
}
