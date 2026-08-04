// SPDX-License-Identifier: 0BSD
import 'package:firebase_core/firebase_core.dart';

/// Owner-replaceable Firebase configuration seam (#426).
///
/// This STUB returns null, which tells [FirebasePushConnector] that
/// Firebase is not configured yet — the app then falls back to
/// UnifiedPush and everything keeps working. To light FCM up:
///
///   1. `dart pub global activate flutterfire_cli`
///   2. `flutterfire configure` (creates the Firebase apps and writes
///      lib/firebase_options.dart)
///   3. Replace the body below with
///      `DefaultFirebaseOptions.currentPlatform` from that file.
///
/// Full checklist: docs/guides/push-setup.md.
abstract final class DeskiloFirebaseOptions {
  static FirebaseOptions? get currentPlatformOrNull => null;
}
