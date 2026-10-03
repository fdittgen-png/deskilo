// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the task package round-trips the canonical recording with its
// transcript, media and claims, byte for byte the same each time, and an
// untrusted package is refused before anything in it is used: size,
// not-a-zip, entry count, traversal/absolute/backslash/case/nested
// paths, duplicates, symbolic links, forged sizes and zip bombs (counted
// while inflating), unlisted, missing or altered files, a manifest that
// disagrees with its recording, and a recording the validator refuses.
// Claims are kept as claims and grant nothing.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/package/task_package.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

Uint8List _zip(
  Map<String, List<int>> files, {
  Map<String, int> modes = const {},
}) {
  final archive = Archive();
  for (final e in files.entries) {
    final f = ArchiveFile.bytes(e.key, e.value)..lastModTime = 0x21000000;
    final mode = modes[e.key];
    if (mode != null) f.mode = mode;
    archive.add(f);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Map<String, Uint8List> _unzip(Uint8List bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes).files)
    if (f.isFile) f.name: f.content,
};

String _shaOf(List<int> b) => sha256.convert(b).toString();

Uint8List _unzipRezip(
  Map<String, Uint8List> files,
  Map<String, List<int>> extra,
) => _zip({...files, ...extra});

/// Rewrites one 4-byte little-endian field of [name]'s local and central
/// headers: the declared uncompressed size, to forge it.
Uint8List _forgeSize(Uint8List zip, String name, int size) {
  final out = Uint8List.fromList(zip);
  final nameBytes = ascii.encode(name);
  final view = ByteData.sublistView(out);
  for (var i = 0; i + 4 < out.length; i++) {
    final sig = view.getUint32(i, Endian.little);
    final local = sig == 0x04034b50;
    final central = sig == 0x02014b50;
    if (!local && !central) continue;
    final nameAt = i + (local ? 30 : 46);
    final lenAt = i + (local ? 26 : 28);
    if (nameAt + nameBytes.length > out.length) continue;
    if (view.getUint16(lenAt, Endian.little) != nameBytes.length) continue;
    var same = true;
    for (var j = 0; j < nameBytes.length; j++) {
      if (out[nameAt + j] != nameBytes[j]) same = false;
    }
    if (!same) continue;
    view.setUint32(i + (local ? 22 : 24), size, Endian.little);
  }
  return out;
}

void main() {
  late TaskRecording recording;
  setUp(() async {
    recording = (await recordFixture(BookingJourney.planConfirmed)).recording;
  });

  Uint8List pack({List<TaskPackageAsset> assets = const []}) =>
      writeTaskPackage(
        recording,
        transcript: '1. Opened Reserve\n2. Chose the day\n',
        assets: assets,
        claims: const {'title': 'Book a desk', 'reviewed': 'yes'},
      );

  TaskPackageIssueCode? refusal(
    Uint8List bytes, {
    TaskPackageLimits limits = const TaskPackageLimits(),
  }) => readTaskPackage(bytes, limits: limits).issues.firstOrNull;

  test('round trip: recording, transcript, media and claims come back', () {
    final png = Uint8List.fromList(List.generate(64, (i) => i));
    final bytes = pack(assets: [TaskPackageAsset('media/step-1.png', png)]);
    final read = readTaskPackage(bytes);
    expect(read.accepted, isTrue, reason: '${read.issues}');
    final p = read.package!;
    expect(encodeRecordingText(p.recording), encodeRecordingText(recording));
    expect(p.runnable, isTrue);
    expect(p.transcript, startsWith('1. Opened Reserve'));
    expect(p.assets.single.bytes, png);
    expect(p.assets.single.mediaType, 'image/png');
    expect(p.claims, {'title': 'Book a desk', 'reviewed': 'yes'});
    expect(
      pack(assets: [TaskPackageAsset('media/step-1.png', png)]),
      bytes,
      reason: 'the same recording packs to the same bytes',
    );
  });

  test('no canary survives into any file of the package', () async {
    for (final journey in BookingJourney.values) {
      final r = (await recordFixture(journey)).recording;
      final files = _unzip(writeTaskPackage(r, transcript: 'steps'));
      final text = files.values.map(utf8.decode).join();
      for (final c in [...privateCanaries, ...canaryFragments]) {
        expect(text.contains(c), isFalse, reason: '${journey.file}: $c');
      }
    }
  });

  test('size, format and entry count are refused before anything else', () {
    expect(
      refusal(pack(), limits: const TaskPackageLimits(maxPackageBytes: 10)),
      TaskPackageIssueCode.tooLarge,
    );
    expect(
      refusal(Uint8List.fromList(utf8.encode('not a zip at all'))),
      TaskPackageIssueCode.notAZip,
    );
    final many = {
      for (var i = 0; i < 70; i++) 'media/f$i.png': [1],
    };
    expect(refusal(_zip(many)), TaskPackageIssueCode.tooManyEntries);
  });

  test('paths outside the allow-list are refused, unsafe ones as unsafe', () {
    final files = _unzip(pack());
    for (final bad in [
      '../escape.json',
      '/etc/passwd',
      r'media\x.png',
      'C:/x.png',
      'media/../recording.json',
      'media//x.png',
    ]) {
      expect(
        refusal(
          _zip({
            ...files,
            bad: [1],
          }),
        ),
        TaskPackageIssueCode.unsafePath,
        reason: bad,
      );
    }
    for (final odd in [
      'Recording.json',
      'media/x.zip',
      'media/X.png',
      'script.js',
      'media/é.png',
      'media/sub/x.png',
    ]) {
      expect(
        refusal(
          _zip({
            ...files,
            odd: [1],
          }),
        ),
        TaskPackageIssueCode.unexpectedEntry,
        reason: odd,
      );
    }
  });

  test('a duplicate entry and a symbolic link are refused', () {
    final files = _unzip(pack());
    final twins = _zip({
      ...files,
      'media/aa.png': [1],
      'media/ab.png': [2],
    });
    // Rename the second to the first, in both headers.
    final patched = Uint8List.fromList(twins);
    final from = ascii.encode('media/ab.png');
    final to = ascii.encode('media/aa.png');
    for (var i = 0; i + from.length <= patched.length; i++) {
      var hit = true;
      for (var j = 0; j < from.length && hit; j++) {
        if (patched[i + j] != from[j]) hit = false;
      }
      if (hit) patched.setRange(i, i + to.length, to);
    }
    expect(refusal(patched), TaskPackageIssueCode.duplicateEntry);

    final link = _zip(
      {...files, 'media/link.png': utf8.encode('/etc/passwd')},
      modes: {'media/link.png': 0xA1FF},
    );
    expect(refusal(link), TaskPackageIssueCode.symbolicLink);
  });

  test('a zip bomb stops at the cap while inflating, forged size or not', () {
    final files = _unzip(pack());
    final bomb = _zip({
      ...files,
      'media/bomb.png': List.filled(4 * 1024 * 1024, 0),
    });
    const tight = TaskPackageLimits(maxMediaBytes: 1024 * 1024);
    expect(refusal(bomb, limits: tight), TaskPackageIssueCode.entryTooLarge);
    final forged = _forgeSize(bomb, 'media/bomb.png', 1000);
    expect(
      refusal(forged, limits: tight),
      TaskPackageIssueCode.entryTooLarge,
      reason: 'the declared size is not trusted',
    );
    expect(
      refusal(
        _unzipRezip(files, {'media/a.png': List.filled(600 * 1024, 1)}),
        limits: const TaskPackageLimits(maxExpandedBytes: 500 * 1024),
      ),
      TaskPackageIssueCode.expandedTooLarge,
    );
    final shortClaim = _forgeSize(pack(), 'transcript.md', 3);
    expect(refusal(shortClaim), TaskPackageIssueCode.sizeMismatch);
  });

  test('unlisted, missing and altered files are refused', () {
    final files = _unzip(pack());
    expect(
      refusal(
        _zip({
          ...files,
          'media/extra.png': [1, 2],
        }),
      ),
      TaskPackageIssueCode.unlistedFile,
    );
    expect(
      refusal(_zip({...files}..remove('transcript.md'))),
      TaskPackageIssueCode.missingFile,
    );
    expect(
      refusal(_zip({...files}..remove('manifest.json'))),
      TaskPackageIssueCode.missingManifest,
    );
    final altered = {...files, 'transcript.md': utf8.encode('1. Paid')};
    expect(refusal(_zip(altered)), TaskPackageIssueCode.checksumMismatch);
  });

  test('a manifest that lies about its recording, or a bad recording', () {
    final files = _unzip(pack());
    Map<String, Object?> manifest() =>
        (jsonDecode(utf8.decode(files['manifest.json']!)) as Map)
            .cast<String, Object?>();
    final lying = manifest();
    (lying['recording']! as Map)['completeness'] = 'interrupted';
    expect(
      refusal(
        _zip({...files, 'manifest.json': utf8.encode(jsonEncode(lying))}),
      ),
      TaskPackageIssueCode.inconsistent,
    );

    final future = manifest()..['package_version'] = 3;
    expect(
      refusal(
        _zip({...files, 'manifest.json': utf8.encode(jsonEncode(future))}),
      ),
      TaskPackageIssueCode.unsupportedVersion,
    );

    final extraKey = manifest()..['execute'] = 'https://canary.invalid';
    expect(
      refusal(
        _zip({...files, 'manifest.json': utf8.encode(jsonEncode(extraKey))}),
      ),
      TaskPackageIssueCode.badManifest,
    );

    // A hostile recording with a valid checksum still meets the validator.
    final hostile = utf8.encode(fixtureText('reject_unsafe_payload'));
    final rebuilt = writeTaskPackage(recording, transcript: 'x');
    final rf = _unzip(rebuilt);
    final m = (jsonDecode(utf8.decode(rf['manifest.json']!)) as Map)
        .cast<String, Object?>();
    final rec = m['recording']! as Map;
    rec['bytes'] = hostile.length;
    rec['sha256'] = _shaOf(hostile);
    final read = readTaskPackage(
      _zip({
        ...rf,
        'recording.json': hostile,
        'manifest.json': utf8.encode(jsonEncode(m)),
      }),
    );
    expect(read.issues, [TaskPackageIssueCode.badRecording]);
    expect(
      read.recordingIssues.map((i) => i.code),
      contains(RecordingIssueCode.unsafePayload),
    );
  });

  test('claims are words, bounded, and grant nothing', () {
    final files = _unzip(pack());
    final m = (jsonDecode(utf8.decode(files['manifest.json']!)) as Map)
        .cast<String, Object?>();
    m['claims'] = {'scope': 'global admin', 'approved': 'yes'};
    final read = readTaskPackage(
      _zip({...files, 'manifest.json': utf8.encode(jsonEncode(m))}),
    );
    expect(read.package!.claims['scope'], 'global admin');
    m['claims'] = {'Bad Key': 'x'};
    expect(
      refusal(_zip({...files, 'manifest.json': utf8.encode(jsonEncode(m))})),
      TaskPackageIssueCode.badManifest,
    );
  });
}
