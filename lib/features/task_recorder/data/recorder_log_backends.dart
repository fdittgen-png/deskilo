// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the two real places a recording log lives: a file per
// recording under the app-support directory (every platform with a
// disk), and shared_preferences in a browser, whose page has no folder.
// Both bound what they hold; neither sends anything anywhere.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recorder_store.dart';

/// A file per recording under `<app support>/task_recordings`.
class FileRecorderLogBackend implements RecorderLogBackend {
  /// [directory] pins the folder (tests); production resolves it lazily.
  FileRecorderLogBackend({Directory? directory}) : _dir = directory;

  Directory? _dir;

  Future<Directory> _folder() async {
    final existing = _dir;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/task_recordings');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _dir = dir;
  }

  Future<File> _file(String key) async {
    if (!recorderKeyPattern.hasMatch(key)) {
      // Keys are digests; nothing else may become a path.
      throw ArgumentError.value(key, 'key', 'not a recording key');
    }
    return File('${(await _folder()).path}/$key.jsonl');
  }

  @override
  Future<void> append(String key, String text) async {
    final file = await _file(key);
    await file.writeAsString(text, mode: FileMode.append, flush: true);
  }

  @override
  Future<void> replace(String key, String text) async {
    final file = await _file(key);
    final staging = await file.parent.createTemp('.guide-');
    try {
      final staged = File('${staging.path}/value');
      await staged.writeAsString(text, flush: true);
      // Same-filesystem rename: readers see the old or new complete value.
      await staged.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  @override
  Future<String?> read(String key) async {
    final file = await _file(key);
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  @override
  Future<List<String>> keys(String prefix) async {
    final dir = await _folder();
    return [
      for (final entity in dir.listSync())
        if (entity is File && entity.path.endsWith('.jsonl'))
          if (entity.uri.pathSegments.last case final name
              when name.startsWith(prefix))
            name.substring(0, name.length - '.jsonl'.length),
    ]..sort();
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (file.existsSync()) await file.delete();
  }
}

/// One shared_preferences string per recording (the browser's local
/// storage). Only what the page itself can keep: it is lost with the
/// site data, and it is never sent.
class PrefsRecorderLogBackend implements RecorderLogBackend {
  PrefsRecorderLogBackend({Future<SharedPreferences>? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefs;

  static const _prefix = 'task_recorder.';

  @override
  Future<void> append(String key, String text) async {
    final prefs = await _prefs;
    final ok = await prefs.setString(
      '$_prefix$key',
      '${prefs.getString('$_prefix$key') ?? ''}$text',
    );
    if (!ok) throw const FileSystemException('local storage refused a write');
  }

  @override
  Future<void> replace(String key, String text) async {
    final prefs = await _prefs;
    try {
      if (!await prefs.setString('$_prefix$key', text)) {
        throw const FileSystemException('local storage refused a write');
      }
    } on Object {
      // setString changes its memory cache before persistence completes.
      await prefs.reload();
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) async =>
      (await _prefs).getString('$_prefix$key');

  @override
  Future<List<String>> keys(String prefix) async => [
    for (final k in (await _prefs).getKeys())
      if (k.startsWith('$_prefix$prefix')) k.substring(_prefix.length),
  ]..sort();

  @override
  Future<void> delete(String key) async =>
      (await _prefs).remove('$_prefix$key');
}
