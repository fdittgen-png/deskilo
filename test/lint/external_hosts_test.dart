// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4423 -- a web address outside this app is spelled once. A host quoted in
// two or more hand-written files of lib/ is a second caller that should read
// `ExternalHosts` (lib/core/links/external_hosts.dart). The generated
// translations and the Demo's invented addresses are not callers. The list
// is held empty.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _host = RegExp(r'https?://([a-z0-9.-]+\.[a-z]{2,})');

/// For each host, the files that quote it: only the hosts of two or more
/// files. Comment lines are no callers.
Map<String, Set<String>> sharedHosts(Map<String, String> sources) {
  final byHost = <String, Set<String>>{};
  for (final MapEntry(key: file, value: source) in sources.entries) {
    for (final line in source.split('\n')) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in _host.allMatches(line)) {
        (byHost[m.group(1)!] ??= {}).add(file);
      }
    }
  }
  return {
    for (final e in byHost.entries)
      if (e.value.length >= 2) e.key: e.value,
  };
}

void main() {
  test('a host in two files is shared; a comment is no caller', () {
    expect(
      sharedHosts({
        'a.dart': "const a = 'https://docs.example.org/x';",
        'b.dart': "const b = 'https://docs.example.org/y';\n// https://other.example.org",
        'c.dart': "const c = 'https://other.example.org';",
      }).keys,
      ['docs.example.org'],
    );
  });

  test('no host is quoted by two hand-written files of lib/', () {
    final sources = {
      for (final f in handWrittenDartFiles('lib'))
        if (!f.path.replaceAll('\\', '/').contains('lib/core/demo/'))
          f.path: f.readAsStringSync(),
    };
    final shared = sharedHosts(sources);
    expect(
      shared,
      isEmpty,
      reason: 'a host two files quote: read it from ExternalHosts: '
          '${shared.entries.map((e) => '${e.key} (${e.value.join(', ')})').join('; ')}',
    );
  });
}
