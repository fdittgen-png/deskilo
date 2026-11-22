// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- what a device needs to know about its scanner: the longest gap between two keys of one scan
// and what ends the code. They belong to the DEVICE (one handheld types faster than another), so they are kept
// on the device with a UI point in Stock settings; whether scanning is used at all is the business's feature.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_stores.dart';
import 'scan_detector.dart';

/// The scanner's timing and terminator on this device.
class ScanPrefs {
  const ScanPrefs({this.intervalMs = defaultIntervalMs, this.terminator = ScanTerminator.either});

  /// The default longest gap between two keys of a scan, in milliseconds.
  static const defaultIntervalMs = 50;

  /// The range a person may choose from (slower scanners and slow tablets need more room).
  static const minIntervalMs = 10;
  static const maxIntervalMs = 500;

  final int intervalMs;
  final ScanTerminator terminator;

  Duration get interval => Duration(milliseconds: intervalMs);

  ScanPrefs copyWith({int? intervalMs, ScanTerminator? terminator}) =>
      ScanPrefs(intervalMs: (intervalMs ?? this.intervalMs).clamp(minIntervalMs, maxIntervalMs), terminator: terminator ?? this.terminator);

  Map<String, Object?> toJson() => {'interval_ms': intervalMs, 'terminator': terminator.wire};

  static ScanPrefs fromJson(Object? json) {
    if (json is! Map) return const ScanPrefs();
    final ms = json['interval_ms'];
    return const ScanPrefs().copyWith(
      intervalMs: ms is int ? ms : null,
      terminator: ScanTerminator.fromWire(json['terminator'] as String?),
    );
  }
}

/// Where the preferences are kept (the app's device storage; tests and the Demo keep them in memory).
abstract interface class ScanPrefsStore {
  Future<ScanPrefs> read();

  Future<void> write(ScanPrefs prefs);
}

/// The preferences in the device's storage.
class SharedScanPrefsStore implements ScanPrefsStore {
  const SharedScanPrefsStore();

  static const _store = PrefsStringStore('scan_prefs');

  @override
  Future<ScanPrefs> read() async {
    final raw = await _store.read();
    if (raw == null) return const ScanPrefs();
    try {
      return ScanPrefs.fromJson(jsonDecode(raw));
    } on FormatException {
      return const ScanPrefs();
    }
  }

  @override
  Future<void> write(ScanPrefs prefs) => _store.write(jsonEncode(prefs.toJson()));
}

/// The preferences in memory: the Demo and the tests.
class InMemoryScanPrefsStore implements ScanPrefsStore {
  ScanPrefs _prefs = const ScanPrefs();

  @override
  Future<ScanPrefs> read() async => _prefs;

  @override
  Future<void> write(ScanPrefs prefs) async => _prefs = prefs;
}

/// The store; the app uses the device's, the Demo and the tests replace it.
final scanPrefsStoreProvider = Provider<ScanPrefsStore>((ref) => const SharedScanPrefsStore());

/// The device's scanner preferences, read once and changed through [ScanPrefsController].
final scanPrefsProvider = AsyncNotifierProvider<ScanPrefsController, ScanPrefs>(ScanPrefsController.new, retry: (_, _) => null);

class ScanPrefsController extends AsyncNotifier<ScanPrefs> {
  @override
  Future<ScanPrefs> build() => ref.watch(scanPrefsStoreProvider).read();

  /// Keeps [prefs] on the device and uses them from now on.
  Future<void> save(ScanPrefs prefs) async {
    await ref.read(scanPrefsStoreProvider).write(prefs);
    state = AsyncData(prefs);
  }
}
