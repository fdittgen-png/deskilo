// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3473 -- the CI toolchain downloads come from a cache first and are checked
// against a pinned SHA-256; a CACHED copy that fails its digest is replaced by
// a fresh download, never fatal (a cache key is immutable, so a corrupt entry
// would otherwise keep the job red until somebody bumped the key). The shell
// is exercised for real, with a `curl` that serves known bytes and records
// that it was called.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _good = 'the pinned bytes';
final _goodSha = sha256.convert(utf8.encode(_good)).toString();

late Directory _tmp;

Future<ProcessResult> _bash(String script, {Map<String, String>? env}) =>
    Process.run('bash', ['-c', script], environment: env);

/// A directory with a fake `curl`: writes [_good] to its `-o` target and
/// appends a line to `calls`.
String _fakeCurl() {
  final dir = Directory('${_tmp.path}/fakebin')..createSync();
  File('${dir.path}/curl').writeAsStringSync('''#!/usr/bin/env bash
out=""
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-o" ]; then out="\$2"; fi
  shift
done
echo called >> "${_tmp.path}/calls"
printf '%s' '$_good' > "\$out"
''');
  Process.runSync('chmod', ['+x', '${dir.path}/curl']);
  return dir.path;
}

int _calls() {
  final f = File('${_tmp.path}/calls');
  return f.existsSync() ? f.readAsLinesSync().length : 0;
}

void main() {
  setUp(() => _tmp = Directory.systemTemp.createTempSync('toolchain_cache'));
  tearDown(() => _tmp.deleteSync(recursive: true));

  group('install_gitleaks.sh obtain_archive', () {
    Future<ProcessResult> run(String cached, String expected) => _bash(
      'source scripts/install_gitleaks.sh; '
      'obtain_archive https://example.invalid/x.tgz "$cached" $expected '
      '"${_tmp.path}/out"',
      env: {
        ...Platform.environment,
        'PATH': '${_fakeCurl()}:${Platform.environment['PATH']}',
      },
    );

    test('a warm, intact cache asks no server', () async {
      final cached = File('${_tmp.path}/cache/a.tgz')
        ..createSync(recursive: true)
        ..writeAsStringSync(_good);
      final r = await run(cached.path, _goodSha);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 0);
      expect(File('${_tmp.path}/out').readAsStringSync(), _good);
    });

    test(
      'a corrupted cached archive is replaced by a fresh download',
      () async {
        final cached = File('${_tmp.path}/cache/a.tgz')
          ..createSync(recursive: true)
          ..writeAsStringSync('corrupted');
        final r = await run(cached.path, _goodSha);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        expect(_calls(), 1, reason: 'one download to heal the cache');
        expect(cached.readAsStringSync(), _good, reason: 'the cache healed');
        expect(File('${_tmp.path}/out').readAsStringSync(), _good);
        expect('${r.stderr}', contains('failed its checksum'));
      },
    );

    test('a cold cache downloads, verifies and keeps the archive', () async {
      final cached = '${_tmp.path}/cache/new.tgz';
      final r = await run(cached, _goodSha);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 1);
      expect(File(cached).readAsStringSync(), _good);
    });

    test(
      'a download that fails the pinned digest is refused, never cached',
      () async {
        final cached = '${_tmp.path}/cache/new.tgz';
        final r = await run(cached, 'f' * 64);
        expect(r.exitCode, isNot(0));
        expect('${r.stderr}', contains('checksum mismatch'));
        expect(File(cached).existsSync(), isFalse);
      },
    );
  });

  group('validate.sh fetch', () {
    Future<ProcessResult> run(String cacheFile, String want) {
      final cacheDir = '${_tmp.path}/vcache';
      if (cacheFile.isNotEmpty) {
        File('$cacheDir/$want')
          ..createSync(recursive: true)
          ..writeAsStringSync(cacheFile);
      }
      return _bash(
        'set -euo pipefail; cache="$cacheDir"; '
        '''eval "\$(sed -n '/^sha() {/,/^}/p;/^fetch() {/,/^}/p' tool/einvoice/validate.sh)"; '''
        'fetch https://example.invalid/v.jar "${_tmp.path}/v.jar" $want',
        env: {
          ...Platform.environment,
          'PATH': '${_fakeCurl()}:${Platform.environment['PATH']}',
        },
      );
    }

    test('an intact cached download asks no server', () async {
      final r = await run(_good, _goodSha);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 0);
    });

    test('a corrupted cached download is replaced by a fresh one', () async {
      final r = await run('corrupted', _goodSha);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 1);
      expect(
        File('${_tmp.path}/vcache/$_goodSha').readAsStringSync(),
        _good,
        reason: 'the cache healed',
      );
      expect(File('${_tmp.path}/v.jar').readAsStringSync(), _good);
    });

    test('a download that fails its pinned digest fails the job', () async {
      final r = await run('', 'e' * 64);
      expect(r.exitCode, isNot(0));
      expect('${r.stderr}', contains('changed'));
    });
  });

  group('verify_cached_deno.sh', () {
    test('a cached Deno that fails its digest is cleared', () async {
      final dir = Directory('${_tmp.path}/deno/2.9.8/x64')
        ..createSync(recursive: true);
      File('${dir.path}/deno').writeAsStringSync('not the pinned binary');
      final r = await _bash(
        'bash scripts/verify_cached_deno.sh clear "${_tmp.path}/deno"',
      );
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(Directory('${_tmp.path}/deno').existsSync(), isFalse);
      expect('${r.stderr}', contains('failed its checksum'));
    });

    test('an empty tool cache is left alone', () async {
      Directory('${_tmp.path}/deno').createSync();
      final r = await _bash(
        'bash scripts/verify_cached_deno.sh clear "${_tmp.path}/deno"',
      );
      expect(r.exitCode, 0);
      expect(Directory('${_tmp.path}/deno').existsSync(), isTrue);
    });

    test('the binary about to run must be the pinned one', () async {
      final bin = File('${_tmp.path}/deno')..writeAsStringSync('imposter');
      final r = await _bash(
        'bash scripts/verify_cached_deno.sh check ${bin.path}',
      );
      expect(r.exitCode, isNot(0));
      expect('${r.stderr}', contains('Deno checksum mismatch'));
    });
  });
}
