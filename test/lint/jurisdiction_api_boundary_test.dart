// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 (of #3328) -- the architecture of the jurisdiction contract. The API
// package is pure Dart that an add-on can depend on without the application:
// it imports no `lib/`, no Flutter, no Supabase, no Riverpod, no platform
// library, and its contract reads no clock. It may depend on `crypto` (its
// artifacts carry a digest) and nothing else.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_jurisdiction_api';

/// What the package's sources may import: the core libraries it uses, `crypto`
/// for the digest, and its own files.
bool _allowed(String uri) =>
    uri == 'dart:typed_data' ||
    uri == 'dart:convert' ||
    uri.startsWith('package:crypto/') ||
    uri.startsWith('package:deskilo_jurisdiction_api/') ||
    (!uri.contains(':') && !uri.contains('..'));

/// The packages that write XML and so depend on `xml` (by name; a new one is a
/// reviewed addition here).
const _xmlPackages = {
  'deskilo_jurisdiction_de',
  'deskilo_jurisdiction_ch',
  'deskilo_jurisdiction_it',
};

void main() {
  test('the API package imports nothing but core Dart, crypto and itself', () {
    final bad = <String>[];
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = filesWithExtension('$_root/lib', '.dart', recursive: true);
    expect(sources, isNotEmpty);
    for (final f in sources) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final m = importRe.firstMatch(line);
        if (m != null && !_allowed(m.group(1)!)) {
          bad.add('${f.path}:${i + 1}: ${m.group(1)}');
        }
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'the contract may not reach the application, Flutter, '
          'Supabase, Riverpod or a platform library:\n${bad.join('\n')}',
    );
  });

  test('the API package depends on crypto alone', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, ['crypto']);
  });

  test('the contract reads no clock and no environment', () {
    final bad = <String>[];
    for (final f in filesWithExtension(
      '$_root/lib',
      '.dart',
      recursive: true,
    )) {
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final needle in [
        'DateTime.now',
        'Platform.',
        'HttpClient',
        'Process.',
      ]) {
        if (code.contains(needle)) bad.add('${f.path}: $needle');
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'an implementation reads its inputs, not the world:\n'
          '${bad.join('\n')}',
    );
  });

  test('the application resolves jurisdictions through the resolver, never '
      'through the country catalogue (no France fallback)', () {
    final resolver = File('lib/core/jurisdiction/jurisdiction_resolver.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      resolver,
      isNot(contains('CountryCatalog')),
      reason: 'CountryCatalog.byCode answers France for an unknown code',
    );
  });

  // #3332 -- a country add-on is the same kind of package: it imports core
  // Dart, the contract and itself, depends on the contract alone and reads no
  // clock or environment. A package added later is held to this by its name.
  test('every country add-on package depends on the contract alone (and xml only where it writes XML)', () {
    final countries = [
      for (final n in directoryNames('packages'))
        if (n.startsWith('deskilo_jurisdiction_') &&
            n != 'deskilo_jurisdiction_api')
          n,
    ];
    expect(countries, isNotEmpty, reason: 'the French add-on at least');
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final bad = <String>[];
    for (final name in countries) {
      final root = 'packages/$name';
      final pubspec = File('$root/pubspec.yaml').readAsStringSync();
      final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!
          .split('\n')
          .where(
            (l) =>
                l.startsWith('  ') &&
                !l.startsWith('    ') &&
                l.trim().isNotEmpty,
          )
          .map((l) => l.trim().split(':').first)
          .toList();
      final wantsXml = _xmlPackages.contains(name);
      final expected = ['deskilo_jurisdiction_api', if (wantsXml) 'xml'];
      if (deps.join(',') != expected.join(',')) {
        bad.add('$root/pubspec.yaml: dependencies are $deps, want $expected');
      }
      for (final f in filesWithExtension(
        '$root/lib',
        '.dart',
        recursive: true,
      )) {
        final lines = f.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          final m = importRe.firstMatch(line);
          final uri = m?.group(1);
          if (uri != null &&
              !(uri == 'dart:typed_data' ||
                  uri == 'dart:convert' ||
                  uri.startsWith('package:deskilo_jurisdiction_api/') ||
                  (wantsXml && uri.startsWith('package:xml/')) ||
                  uri.startsWith('package:$name/') ||
                  (!uri.contains(':') && !uri.contains('..')))) {
            bad.add('${f.path}:${i + 1}: $uri');
          }
          final code = line.trimLeft();
          if (!code.startsWith('//')) {
            for (final needle in [
              'DateTime.now',
              'Platform.',
              'HttpClient',
              'Process.',
            ]) {
              if (code.contains(needle)) bad.add('${f.path}:${i + 1}: $needle');
            }
          }
        }
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'a country add-on may reach the contract only:\n${bad.join('\n')}',
    );
  });
}
