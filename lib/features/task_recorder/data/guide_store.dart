// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The task wizard's own guides, kept on this device for this account.
//
// A guide is made from a recording (or arrives in a task file or package)
// and then lives here until its owner deletes it, so it can be started
// again without the recording it came from. It is stored in the same kind
// of place a recording is — a file per guide, or the browser's own storage
// — under a namespace of its own, so a guide is never mistaken for a
// recording and the recordings list never shows one. Nothing is sent
// anywhere. A guide is the encoded text the guide codec already reads and
// writes; nothing is stored that the codec would refuse.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../domain/stored_guide.dart';
import '../guide/guide_codec.dart';
import '../guide/task_guide.dart';
import 'recorder_store.dart';

class GuideStore {
  GuideStore({
    required this._backend,
    required String accountNamespace,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure(),
       _namespace = _guideNamespace(accountNamespace);

  final RecorderLogBackend _backend;
  final DateTime Function() _now;
  final Random _random;
  final String _namespace;

  /// The guides live under a namespace derived from the account's, so
  /// they can never share a prefix with its recordings.
  static String _guideNamespace(String accountNamespace) =>
      sha256.convert(utf8.encode('$accountNamespace:guides')).toString().substring(0, 32);

  String get _prefix => 'tr1.$_namespace.';

  String _newId() => [
    for (var i = 0; i < 32; i++) _random.nextInt(16).toRadixString(16),
  ].join();

  String _key(String id) {
    final key = '$_prefix$id';
    if (!recorderKeyPattern.hasMatch(key)) {
      throw ArgumentError.value(id, 'id', 'not a guide id');
    }
    return key;
  }

  /// Adds [guide] to the library and answers its id. A guide the codec
  /// would not read back is refused rather than stored.
  Future<String> add(TaskGuide guide) async {
    final text = encodeGuideText(guide);
    if (!decodeGuideText(text).accepted) {
      throw ArgumentError.value(guide.title, 'guide', 'not a readable guide');
    }
    final id = _newId();
    await _backend.append(
      _key(id),
      '${jsonEncode({'created': _now().millisecondsSinceEpoch, 'guide': encodeGuide(guide)})}\n',
    );
    return id;
  }

  /// Replaces the guide [id] with [guide] (an edited draft).
  Future<void> replace(String id, TaskGuide guide) async {
    final text = encodeGuideText(guide);
    if (!decodeGuideText(text).accepted) {
      throw ArgumentError.value(guide.title, 'guide', 'not a readable guide');
    }
    final key = _key(id);
    final existing = await _read(key);
    await _backend.delete(key);
    await _backend.append(
      key,
      '${jsonEncode({'created': (existing?.createdAt ?? _now()).millisecondsSinceEpoch, 'guide': encodeGuide(guide)})}\n',
    );
  }

  /// The library, newest first. An entry this build cannot read is left
  /// out (it stays on the device until deleted by hand or overwritten).
  Future<List<StoredGuide>> list() async {
    final out = <StoredGuide>[];
    for (final key in await _backend.keys(_prefix)) {
      if (!recorderKeyPattern.hasMatch(key)) continue;
      final guide = await _read(key);
      if (guide != null) out.add(guide);
    }
    out.sort(
      (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
        a.createdAt?.millisecondsSinceEpoch ?? 0,
      ),
    );
    return out;
  }

  Future<void> delete(String id) => _backend.delete(_key(id));

  Future<StoredGuide?> _read(String key) async {
    final raw = await _backend.read(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw.trim()) as Map<String, Object?>;
      final decoded = decodeGuideText(jsonEncode(map['guide']));
      final guide = decoded.guide;
      if (guide == null) return null;
      final created = map['created'];
      return StoredGuide(
        id: key.substring(_prefix.length),
        guide: guide,
        createdAt: created is int
            ? DateTime.fromMillisecondsSinceEpoch(created)
            : null,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
