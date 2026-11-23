// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- what a device needs to know about its scanner: the longest gap between two keys of one scan
// and what ends the code. They belong to the DEVICE (one handheld types faster than another), so they are kept
// on the device with a UI point in Stock settings; whether scanning is used at all is the business's feature.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_stores.dart';
import 'scan_detector.dart';

/// The scanner's timing and terminator on this device.
/// How a code read by the camera is confirmed on the device: nothing, a vibration, or a click.
enum ScanConfirm {
  none('none'),
  vibrate('vibrate'),
  click('click');

  const ScanConfirm(this.wire);

  final String wire;

  static ScanConfirm fromWire(String? wire) => values.firstWhere((c) => c.wire == wire, orElse: () => vibrate);
}

class ScanPrefs {
  const ScanPrefs({this.intervalMs = defaultIntervalMs, this.terminator = ScanTerminator.either, this.confirm = ScanConfirm.vibrate});

  /// The default longest gap between two keys of a scan, in milliseconds.
  static const defaultIntervalMs = 50;

  /// The range a person may choose from (slower scanners and slow tablets need more room).
  static const minIntervalMs = 10;
  static const maxIntervalMs = 500;

  final int intervalMs;
  final ScanTerminator terminator;

  /// #4360 -- how the camera confirms a code it read.
  final ScanConfirm confirm;

  Duration get interval => Duration(milliseconds: intervalMs);

  ScanPrefs copyWith({int? intervalMs, ScanTerminator? terminator, ScanConfirm? confirm}) => ScanPrefs(
    intervalMs: (intervalMs ?? this.intervalMs).clamp(minIntervalMs, maxIntervalMs),
    terminator: terminator ?? this.terminator,
    confirm: confirm ?? this.confirm,
  );

  Map<String, Object?> toJson() => {'interval_ms': intervalMs, 'terminator': terminator.wire, 'confirm': confirm.wire};

  static ScanPrefs fromJson(Object? decoded) {
    if (decoded is! Map) return const ScanPrefs();
    final r = JsonReader.of(decoded, context: 'scan_prefs');
    return const ScanPrefs().copyWith(
      intervalMs: r.intOrNull('interval_ms'),
      terminator: ScanTerminator.fromWire(r.stringOrNull('terminator')),
      confirm: ScanConfirm.fromWire(r.stringOrNull('confirm')),
    );
  }
}

/// Where the preferences are kept (the app's device storage; tests and the Demo keep them in memory).
abstract interface class ScanPrefsStore {
  Future<ScanPrefs> read();

  Future<void> write(ScanPrefs prefs);
}

/// The preferences in the device's storage.
class _SharedScanPrefsStore implements ScanPrefsStore {
  const _SharedScanPrefsStore();

  static const _store = PrefsStringStore('scan_prefs');

  @override
  Future<ScanPrefs> read() async {
    final raw = await _store.read();
    if (raw == null) return const ScanPrefs();
    try {
      return ScanPrefs.fromJson(jsonDecode(raw));
    } on Object {
      // trace-exempt: a stored value that cannot be read is the defaults, never a failure the person must fix
      return const ScanPrefs();
    }
  }

  @override
  Future<void> write(ScanPrefs prefs) => _store.write(jsonEncode(prefs.toJson()));
}

/// The store; the app uses the device's, the Demo and the tests replace it.
final scanPrefsStoreProvider = Provider<ScanPrefsStore>((ref) => const _SharedScanPrefsStore());

/// The device's scanner preferences, read once and changed through [ScanPrefsController].
final scanPrefsProvider = AsyncNotifierProvider<_ScanPrefsController, ScanPrefs>(_ScanPrefsController.new, retry: (_, _) => null);

class _ScanPrefsController extends AsyncNotifier<ScanPrefs> {
  @override
  Future<ScanPrefs> build() => ref.watch(scanPrefsStoreProvider).read();

  /// Keeps [prefs] on the device and uses them from now on.
  Future<void> save(ScanPrefs prefs) async {
    await ref.read(scanPrefsStoreProvider).write(prefs);
    state = AsyncData(prefs);
  }
}
