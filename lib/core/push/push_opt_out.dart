// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 — push delivery is optional processing: it hands a device token
// and a notification to the push service, and the app works without it.
// The person can turn it off on this device; the choice is stored on the
// device, so a restart, a lost connection or a retry cannot turn it back
// on — only the person can.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'push_opt_out.g.dart';

abstract class PushOptOutStore {
  Future<bool> read();
  Future<void> write(bool optedOut);
}

class PrefsPushOptOutStore implements PushOptOutStore {
  const PrefsPushOptOutStore();

  static const _key = 'push_opted_out';

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> write(bool optedOut) async =>
      (await SharedPreferences.getInstance()).setBool(_key, optedOut);
}

@Riverpod(keepAlive: true)
PushOptOutStore pushOptOutStore(Ref ref) => const PrefsPushOptOutStore();

/// True when the person turned push delivery off on this device.
@Riverpod(keepAlive: true)
class PushOptedOut extends _$PushOptedOut {
  @override
  Future<bool> build() => ref.watch(pushOptOutStoreProvider).read();

  Future<void> set(bool optedOut) async {
    await ref.read(pushOptOutStoreProvider).write(optedOut);
    state = AsyncData(optedOut);
  }
}
