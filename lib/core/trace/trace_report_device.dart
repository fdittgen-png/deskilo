// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — what this device keeps for error reports: whether the person lets
// them go (the Privacy switch, on by default, stored on this device only) and
// the random id the installation counts them under as data.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/prefs_stores.dart';

abstract interface class TraceReportDeviceStore {
  /// This device's random report id, made the first time it is asked for.
  Future<String> deviceId();

  /// Whether error reports may leave this device; true until switched off.
  Future<bool> enabled();
  Future<void> setEnabled({required bool on});
}

class _PrefsTraceReportDeviceStore implements TraceReportDeviceStore {
  const _PrefsTraceReportDeviceStore();

  static const _id = PrefsStringStore('trace_report_device_id');
  static const _on = 'trace_reports_on';

  @override
  Future<String> deviceId() async {
    final held = await _id.read();
    if (held != null && _shape.hasMatch(held)) return held;
    final fresh = traceReportDeviceIdOf(Random.secure());
    await _id.write(fresh);
    return fresh;
  }

  @override
  Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(_on) ?? true;

  @override
  Future<void> setEnabled({required bool on}) async =>
      (await SharedPreferences.getInstance()).setBool(_on, on);
}

/// The shape the installation accepts for a device id.
final _shape = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

/// A fresh random device id: 32 hexadecimal digits from [random].
@visibleForTesting
String traceReportDeviceIdOf(Random random) => [
  for (var i = 0; i < 16; i++)
    random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

final traceReportDeviceStoreProvider = Provider<TraceReportDeviceStore>(
  (ref) => const _PrefsTraceReportDeviceStore(),
);

/// Whether error reports may leave this device (Settings › Privacy).
final traceReportsSwitchProvider =
    AsyncNotifierProvider<TraceReportsSwitch, bool>(TraceReportsSwitch.new);

class TraceReportsSwitch extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(traceReportDeviceStoreProvider).enabled();

  Future<void> set({required bool on}) async {
    await ref.read(traceReportDeviceStoreProvider).setEnabled(on: on);
    state = AsyncData(on);
  }
}
