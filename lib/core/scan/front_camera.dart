// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'front_camera.g.dart';

/// Persists which camera reads badge QR codes. Same seam shape as
/// `DevModeStore` so widget tests never touch platform channels.
abstract class FrontCameraStore {
  /// Null while the user never chose a lens — the SURFACE then decides
  /// (#773): kiosks default front, handheld scans default back. The old
  /// `fallback: true` swallowed "unset" and pointed every fresh install's
  /// invite scan at the joiner's face.
  Future<bool?> read();
  Future<void> write(bool enabled);
}

class PrefsFrontCameraStore implements FrontCameraStore {
  const PrefsFrontCameraStore();

  static const _key = 'scan_front_camera';

  @override
  Future<bool?> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key);

  @override
  Future<void> write(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_key, enabled);
}

@Riverpod(keepAlive: true)
FrontCameraStore frontCameraStore(Ref ref) => const PrefsFrontCameraStore();

/// Whether badge scanning uses the FRONT (screen-side) camera — the
/// default: a wall-mounted kiosk tablet has its back camera against the
/// wall, so the badge is held up to the screen. Off = back camera, for
/// handheld devices. Local device preference (camera is hardware).
@Riverpod(keepAlive: true)
class FrontCameraScan extends _$FrontCameraScan {
  @override
  Future<bool?> build() => ref.watch(frontCameraStoreProvider).read();

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    await ref.read(frontCameraStoreProvider).write(enabled);
  }
}
