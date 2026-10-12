// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';

/// Logs in memory, for tests (#2383: moved out of lib/, which never used it).
class MemoryRecorderLogBackend implements RecorderLogBackend {
  final Map<String, StringBuffer> logs = {};

  @override
  Future<void> append(String key, String text) async =>
      (logs[key] ??= StringBuffer()).write(text);

  @override
  Future<void> replace(String key, String text) async =>
      logs[key] = StringBuffer(text);

  @override
  Future<String?> read(String key) async => logs[key]?.toString();

  @override
  Future<List<String>> keys(String prefix) async =>
      logs.keys.where((k) => k.startsWith(prefix)).toList()..sort();

  @override
  Future<void> delete(String key) async => logs.remove(key);
}
