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
if [ -n "\${FIXTURE:-}" ]; then cp "\$FIXTURE" "\$out"; else printf '%s' '$_good' > "\$out"; fi
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

  test('the workflow scanner refuses an unverified download before extraction', () async {
    final dest = '${_tmp.path}/scanner';
    final r = await _bash('bash scripts/install_zizmor.sh "$dest"', env: {
      ...Platform.environment,
      'PATH': '${_fakeCurl()}:${Platform.environment['PATH']}',
    });
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('checksum mismatch'));
    expect(Directory(dest).existsSync(), isFalse);
  });

  test('a failed workflow scanner cannot leave a stale successful report', () async {
    final scanner = File('${_tmp.path}/scanner')..writeAsStringSync(
      '#!/usr/bin/env bash\n'
      'if [[ "\$1" == --version ]]; then echo fixture; exit 0; fi\nexit 23\n',
    );
    Process.runSync('chmod', ['+x', scanner.path]);
    final report = '${_tmp.path}/report';
    File('$report/summary.md')..createSync(recursive: true)..writeAsStringSync('old success');
    final r = await _bash('bash scripts/workflow_audit.sh "${scanner.path}" "$report"');
    expect(r.exitCode, 23);
    expect(File('$report/summary.md').existsSync(), isFalse);
  });

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
    String deno() => '${_tmp.path}/deno';
    Future<ProcessResult> clear({String arch = 'X64', String? sha}) => _bash(
      // `sha` swaps the pinned digest for a fixture's (the real binary is not
      // in the repository); without it the real pin is used
      'source scripts/verify_cached_deno.sh; '
      '${sha == null ? '' : 'expected=$sha; '}'
      'main clear "${deno()}" $arch',
    );
    File binary(String arch, String content, {bool exec = true}) {
      final f = File('${deno()}/2.9.8/$arch/deno')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      if (exec) Process.runSync('chmod', ['+x', f.path]);
      return f;
    }

    String shaOf(String s) => sha256.convert(utf8.encode(s)).toString();

    test('a cached Deno that fails its digest is cleared', () async {
      binary('x64', 'not the pinned binary');
      final r = await clear();
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(Directory(deno()).existsSync(), isFalse);
      expect('${r.stderr}', contains('not exactly the pinned'));
    });

    test('the pinned binary for this arch, executable, is KEPT', () async {
      binary('x64', 'the pinned bytes');
      final r = await clear(sha: shaOf('the pinned bytes'));
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(File('${deno()}/2.9.8/x64/deno').existsSync(), isTrue);
    });

    test('the right digest without the exec bit is cleared', () async {
      binary('x64', 'the pinned bytes', exec: false);
      final r = await clear(sha: shaOf('the pinned bytes'));
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(Directory(deno()).existsSync(), isFalse);
    });

    test('another arch\'s directory only is cleared', () async {
      binary('arm64', 'the pinned bytes');
      final r = await clear(sha: shaOf('the pinned bytes'));
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(Directory(deno()).existsSync(), isFalse);
    });

    test('the runner arch is matched as the tool cache names it', () async {
      binary('arm64', 'the pinned bytes');
      final r = await clear(arch: 'ARM64', sha: shaOf('the pinned bytes'));
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(File('${deno()}/2.9.8/arm64/deno').existsSync(), isTrue);
    });

    test('a .complete marker without a binary is cleared, not trusted', () async {
      final dir = Directory('${deno()}/2.9.8')..createSync(recursive: true);
      File('${dir.path}/x64.complete').writeAsStringSync('');
      Directory('${dir.path}/x64').createSync();
      final r = await clear();
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(
        Directory(deno()).existsSync(),
        isFalse,
        reason:
            'setup-deno would take the marker for a hit and skip the download',
      );
    });

    test('a binary at another version is cleared', () async {
      final f = File('${deno()}/2.9.7/x64/deno')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      Process.runSync('chmod', ['+x', f.path]);
      final r = await clear();
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(Directory(deno()).existsSync(), isFalse);
    });

    test('no cache at all is left alone', () async {
      final r = await clear();
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(Directory(deno()).existsSync(), isFalse);
    });

    test(
      'check: the binary at the pinned path must be the pinned one',
      () async {
        binary('x64', 'imposter');
        final r = await _bash(
          'bash scripts/verify_cached_deno.sh check "${deno()}" X64',
        );
        expect(r.exitCode, isNot(0));
        expect('${r.stderr}', contains('Deno checksum mismatch'));
      },
    );

    test('check fails when nothing is installed for this arch', () async {
      binary('arm64', 'whatever');
      final r = await _bash(
        'bash scripts/verify_cached_deno.sh check "${deno()}" X64',
      );
      expect(r.exitCode, isNot(0));
      expect('${r.stderr}', contains('is not installed for X64'));
    });
  });

  /// A tarball holding one executable [name] that prints [says]; its digest.
  ({String path, String sha, String binarySha}) fixtureTarball(
    String name,
    String says,
  ) {
    final dir = Directory('${_tmp.path}/fixture')..createSync();
    final bin = File('${dir.path}/$name')
      ..writeAsStringSync('#!/bin/sh\necho $says\n');
    Process.runSync('chmod', ['+x', bin.path]);
    final tgz = '${_tmp.path}/fixture.tgz';
    Process.runSync('tar', ['-czf', tgz, '-C', dir.path, name]);
    return (
      path: tgz,
      sha: sha256.convert(File(tgz).readAsBytesSync()).toString(),
      binarySha: sha256.convert(bin.readAsBytesSync()).toString(),
    );
  }

  Map<String, String> env(String fixture) => {
    ...Platform.environment,
    'PATH': '${_fakeCurl()}:${Platform.environment['PATH']}',
    'FIXTURE': fixture,
    // mktemp -d lands here, so a leaked temp directory is visible
    'TMPDIR': (Directory('${_tmp.path}/tmp')..createSync()).path,
  };

  int leftovers() => Directory('${_tmp.path}/tmp').listSync().length;

  group('the whole install scripts', () {
    test(
      'install_gitleaks.sh: cold then warm, exit 0, no temp directory left',
      () async {
        final fx = fixtureTarball('gitleaks', '8.30.1');
        String script(String cache) =>
            'source scripts/install_gitleaks.sh; '
            'pin_for_platform() { platform=fixture; expected=${fx.sha}; }; '
            'main "${_tmp.path}/bin" "$cache"';
        final cache = '${_tmp.path}/cache';
        final cold = await _bash(script(cache), env: env(fx.path));
        expect(cold.exitCode, 0, reason: '${cold.stderr}');
        expect('${cold.stdout}', contains('8.30.1'));
        expect(_calls(), 1);
        expect(leftovers(), 0, reason: 'the scratch directory is removed');
        final warm = await _bash(script(cache), env: env(fx.path));
        expect(warm.exitCode, 0, reason: '${warm.stderr}');
        expect(_calls(), 1, reason: 'a warm cache asks no server');
        expect(leftovers(), 0);
      },
    );

    test('install_gitleaks.sh: runs as a script (the workflow\'s way)', () async {
      // no source, no override: the unsupported-platform and argument paths of
      // the real entry point behave
      final r = await _bash('bash scripts/install_gitleaks.sh');
      expect(r.exitCode, isNot(0));
      expect('${r.stderr}', contains('destination directory required'));
    });

    test(
      'install_supabase_cli.sh: cold, warm and a corrupted cached binary',
      () async {
        final fx = fixtureTarball('supabase', '2.118.0');
        String script() =>
            'source scripts/install_supabase_cli.sh; '
            'pin_for_platform() { asset=fixture.tgz; archive_sha=${fx.sha}; '
            'binary_sha=${fx.binarySha}; }; main "${_tmp.path}/sb"';
        final cold = await _bash(script(), env: env(fx.path));
        expect(cold.exitCode, 0, reason: '${cold.stderr}');
        expect('${cold.stdout}', contains('2.118.0'));
        expect(_calls(), 1);
        expect(leftovers(), 0);
        final warm = await _bash(script(), env: env(fx.path));
        expect(warm.exitCode, 0, reason: '${warm.stderr}');
        expect('${warm.stdout}', contains('Using the cached Supabase CLI'));
        expect(_calls(), 1);
        File('${_tmp.path}/sb/supabase')
            .writeAsStringSync('#!/bin/sh\necho corrupted\n');
        final healed = await _bash(script(), env: env(fx.path));
        expect(healed.exitCode, 0, reason: '${healed.stderr}');
        expect(
          _calls(),
          2,
          reason: 'a corrupted cached binary is downloaded again',
        );
        expect('${healed.stdout}', contains('2.118.0'));
        expect(leftovers(), 0);
      },
    );
  });

  group('install_gradle.sh (#3473)', () {
    // the wrapper's directory for the pinned URL: base 36 of MD5(url). The
    // value is pinned here so a change of the derivation is a red test, not a
    // build that silently downloads the distribution again.
    const url = 'https://services.gradle.org/distributions/gradle-9.1.0-all.zip';
    const wrapperDir =
        'wrapper/dists/gradle-9.1.0-all/7wzd0jkjit61aq2p43wpjgij9';

    String props({String? sha}) {
      final f = File('${_tmp.path}/gradle-wrapper.properties')
        ..writeAsStringSync(
        'distributionBase=GRADLE_USER_HOME\n'
        'distributionUrl=https\\://services.gradle.org/distributions/gradle-9.1.0-all.zip\n'
        '${sha == null ? '' : 'distributionSha256Sum=$sha\n'}',
      );
      return f.path;
    }

    Future<ProcessResult> run(String properties, {String cache = ''}) => _bash(
      'bash scripts/install_gradle.sh "$properties" "${_tmp.path}/home" $cache',
      env: {
        ...Platform.environment,
        'PATH': '${_fakeCurl()}:${Platform.environment['PATH']}',
      },
    );

    File zip() => File('${_tmp.path}/home/$wrapperDir/gradle-9.1.0-all.zip');
    File cachedZip() =>
        File('${_tmp.path}/cache/$_goodSha-gradle-9.1.0-all.zip');

    test('the repository pins the digest of the archive its URL names', () {
      final p = File('android/gradle/wrapper/gradle-wrapper.properties')
          .readAsStringSync();
      expect(p, contains(url.replaceFirst(':', r'\:')));
      expect(p, matches(RegExp(r'distributionSha256Sum=[0-9a-f]{64}\n')));
    });

    test('a cold cache downloads, verifies, keeps it and seeds the wrapper',
        () async {
      final r = await run(props(sha: _goodSha), cache: '${_tmp.path}/cache');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 1);
      expect(zip().readAsStringSync(), _good, reason: 'where the wrapper looks');
      expect(cachedZip().existsSync(), isTrue);
    });

    test('a warm cache works with no download at all', () async {
      cachedZip()
        ..createSync(recursive: true)
        ..writeAsStringSync(_good);
      final r = await run(props(sha: _goodSha), cache: '${_tmp.path}/cache');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 0);
      expect(zip().readAsStringSync(), _good);
    });

    test('a corrupted cached archive is downloaded again', () async {
      cachedZip()
        ..createSync(recursive: true)
        ..writeAsStringSync('corrupted');
      final r = await run(props(sha: _goodSha), cache: '${_tmp.path}/cache');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(_calls(), 1);
      expect('${r.stderr}', contains('failed its checksum'));
      expect(zip().readAsStringSync(), _good);
    });

    test('a restored extracted tree is discarded, never run as it is',
        () async {
      cachedZip()
        ..createSync(recursive: true)
        ..writeAsStringSync(_good);
      final mutated =
          File('${_tmp.path}/home/$wrapperDir/gradle-9.1.0/bin/gradle')
            ..createSync(recursive: true)
            ..writeAsStringSync('mutated');
      final marker =
          File('${_tmp.path}/home/$wrapperDir/gradle-9.1.0-all.zip.ok')
            ..writeAsStringSync('');
      final r = await run(props(sha: _goodSha), cache: '${_tmp.path}/cache');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(mutated.existsSync(), isFalse);
      expect(marker.existsSync(), isFalse);
      expect(zip().readAsStringSync(), _good);
    });

    test('a download that fails the pinned digest is refused and seeds nothing',
        () async {
      final r = await run(props(sha: 'f' * 64), cache: '${_tmp.path}/cache');
      expect(r.exitCode, isNot(0));
      expect('${r.stderr}', contains('checksum mismatch'));
      expect(zip().existsSync(), isFalse);
      expect(Directory('${_tmp.path}/cache').existsSync(), isFalse);
    });

    test('a wrapper with no digest is refused before any download', () async {
      final r = await run(props());
      expect(r.exitCode, 2);
      expect('${r.stderr}', contains('distributionSha256Sum'));
      expect(_calls(), 0);
    });
  });
}
