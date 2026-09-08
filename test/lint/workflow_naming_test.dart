// SPDX-License-Identifier: 0BSD
//
// #1033 — the Actions sidebar is sorted alphabetically by workflow name,
// so the name has to carry the grouping or fourteen workflows read as
// fourteen unrelated file stems: `android-boot`, `dev-apk`, `web`. The
// convention is `<Group> · <what it does>`, the same one Sparkilo
// settled on, so one habit covers both projects' sidebars.
//
// Job names are deliberately NOT checked here: a job name is a required
// status-check context, and renaming one can block auto-merge until
// branch protection is updated in lockstep. Renaming a workflow is free;
// renaming a job is not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _groups = ['CI', 'Nightly', 'Release', 'Publish', 'Status', 'Tools'];

List<File> _workflows() => Directory('.github/workflows')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.yml'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// The workflow's top-level `name:` — the first column-0 `name:` line.
/// A line scanner rather than a YAML parser: the grammar is regular
/// enough, and the test stays dependency-free.
String? _nameOf(File f) {
  for (final line in f.readAsStringSync().split('\n')) {
    if (line.startsWith('name:')) return line.substring(5).trim();
  }
  return null;
}

void main() {
  test('every workflow is named "<Group> · <what it does>"', () {
    final offenders = <String>[];
    for (final f in _workflows()) {
      final name = _nameOf(f);
      if (name == null) {
        offenders.add('${f.path}: no top-level name:');
        continue;
      }
      final parts = name.split(' · ');
      if (parts.length != 2 ||
          !_groups.contains(parts.first) ||
          parts.last.trim().isEmpty) {
        offenders.add('${f.path}: "$name"');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a workflow name must read "<Group> · <what it does>" with '
            'Group one of $_groups — see .github/workflows/README.md. '
            'Offenders:\n${offenders.join('\n')}');
  });

  test('no two workflows share a name', () {
    final byName = <String, List<String>>{};
    for (final f in _workflows()) {
      final name = _nameOf(f);
      if (name != null) byName.putIfAbsent(name, () => []).add(f.path);
    }
    final clashes = byName.entries.where((e) => e.value.length > 1).toList();
    expect(clashes, isEmpty,
        reason: 'two workflows with one name are indistinguishable in every '
            'run list: ${clashes.map((e) => '${e.key} = ${e.value}').join('; ')}');
  });

  test('the description is sentence case, not Title Case', () {
    // Every word after the first that starts upper case must be a real
    // proper noun — the acronyms and product names this project uses.
    const proper = {
      'Add', 'Analyze', 'Android', 'APK', 'APKs', 'App', 'DMG', 'Dev', 'F-Droid',
      'GitHub', 'MSI', 'Pages', 'Play', 'Store', 'TestFlight', 'Train',
      'Web', 'Windows', 'iOS', 'macOS',
    };
    final offenders = <String>[];
    for (final f in _workflows()) {
      final name = _nameOf(f);
      if (name == null || !name.contains(' · ')) continue;
      final words = name.split(' · ').last.split(RegExp(r'[ ()]+'));
      for (final word in words.skip(1)) {
        final bare = word.replaceAll(RegExp(r'[^A-Za-z-]'), '');
        if (bare.isEmpty) continue;
        final first = bare[0];
        if (first == first.toUpperCase() &&
            first != first.toLowerCase() &&
            !proper.contains(bare)) {
          offenders.add('${f.path}: "$bare" in "$name"');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'sentence case after the group — capitalise only proper '
            'nouns. Offenders:\n${offenders.join('\n')}');
  });

  test('a workflow that is called by another is still named for a human', () {
    // The release train calls four workflows by path. Being callable is
    // not a reason to keep a file-stem name: they appear in the sidebar
    // and in every run list exactly like the others.
    for (final f in _workflows()) {
      final body = f.readAsStringSync();
      if (!body.contains('workflow_call:')) continue;
      expect(_nameOf(f), contains(' · '),
          reason: '${f.path} is reusable and still needs a grouped name');
    }
  });
}
