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
            n != 'deskilo_jurisdiction_api' &&
            n != 'deskilo_jurisdiction_standards')
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
      // the contract, the neutral helpers when it uses them, xml only where
      // it writes XML -- nothing else
      final allowedDeps = {
        'deskilo_jurisdiction_api',
        'deskilo_jurisdiction_standards',
        if (wantsXml) 'xml',
      };
      if (!deps.contains('deskilo_jurisdiction_api') ||
          !allowedDeps.containsAll(deps)) {
        bad.add(
          '$root/pubspec.yaml: dependencies are $deps, '
          'allowed ${allowedDeps.toList()..sort()}',
        );
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
                  uri.startsWith('package:deskilo_jurisdiction_standards/') ||
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

  // #3333 review -- the contract exports contract types ONLY: the helpers the
  // application and several add-ons share live in the standards package, so a
  // change to a CSV cell is never a change to the add-on contract.
  test('the API package exports contract types only', () {
    final barrel = File('$_root/lib/deskilo_jurisdiction_api.dart')
        .readAsLinesSync()
        .where((l) => l.startsWith('export '))
        .map((l) => RegExp(r"'([^']+)'").firstMatch(l)!.group(1))
        .toSet();
    expect(
      barrel,
      {
        'src/capability_descriptor.dart',
        'src/filing_context.dart',
        'src/generated_artifact.dart',
        'src/invoice_document_context.dart',
        'src/invoice_profile_contribution.dart',
        'src/validation_result.dart',
        'src/vat_filing_contribution.dart',
      },
      reason: 'a new export is a contract change: review it, then list it here',
    );
  });

  test(
    'the standards package depends on nothing and imports core Dart only',
    () {
      const root = 'packages/deskilo_jurisdiction_standards';
      final pubspec = File('$root/pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        isNot(contains('\ndependencies:')),
        reason: 'neutral helpers: no dependency of any kind',
      );
      final bad = <String>[];
      final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
      for (final f in filesWithExtension(
        '$root/lib',
        '.dart',
        recursive: true,
      )) {
        for (final (i, line) in f.readAsLinesSync().indexed) {
          final uri = importRe.firstMatch(line)?.group(1);
          if (uri != null && (uri.contains(':') || uri.contains('..'))) {
            bad.add('${f.path}:${i + 1}: $uri');
          }
          if (!line.trimLeft().startsWith('//') &&
              ['DateTime.now', 'Platform.', 'HttpClient'].any(line.contains)) {
            bad.add('${f.path}:${i + 1}: reads the world');
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    },
  );
}
