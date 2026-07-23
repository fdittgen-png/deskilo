// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'front_camera.g.dart';

/// Persists which camera reads badge QR codes. Same seam shape as
/// `DevModeStore` so widget tests never touch platform channels.
abstract class FrontCameraStore {
  Future<bool> read();
  Future<void> write(bool enabled);
}

class PrefsFrontCameraStore implements FrontCameraStore {
  static const _key = 'scan_front_camera';

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? true;

  @override
  Future<void> write(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_key, enabled);
}

@Riverpod(keepAlive: true)
FrontCameraStore frontCameraStore(Ref ref) => PrefsFrontCameraStore();

/// Whether badge scanning uses the FRONT (screen-side) camera — the
/// default: a wall-mounted kiosk tablet has its back camera against the
/// wall, so the badge is held up to the screen. Off = back camera, for
/// handheld devices. Local device preference (camera is hardware).
@Riverpod(keepAlive: true)
class FrontCameraScan extends _$FrontCameraScan {
  @override
  Future<bool> build() => ref.watch(frontCameraStoreProvider).read();

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    await ref.read(frontCameraStoreProvider).write(enabled);
  }
}
