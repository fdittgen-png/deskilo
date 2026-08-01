// SPDX-License-Identifier: 0BSD
//
// Licence lint: every source file declares 0BSD, and nothing declares
// anything else.
//
// ADR 0009 relicensed the project from MIT and said every SPDX header
// becomes 0BSD. Ten files were missed — the Gemfile, the three fastlane
// files, both store-upload scripts, the GMS audit, the icon generator, the
// Windows installer authoring and one workflow — and stayed wrong for two
// weeks because nothing checked. A relicence is exactly the kind of sweep
// that is done once, by hand, at scale, and is therefore exactly the kind
// that needs a machine to confirm it finished.
//
// The second assertion matters as much as the first: a file that declares
// MIT is worse than a file that declares nothing, because it is a false
// statement about the terms someone may rely on.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _spdx = 'SPDX-License-Identifier';
const _licence = '0BSD';

/// Trees whose hand-written sources must carry the header.
const _roots = [
  'lib',
  'test',
  'tool',
  'tools',
  'scripts',
  'supabase',
  'integration_test',
  '.github/workflows',
];

const _extensions = ['.dart', '.sh', '.py', '.sql', '.ts', '.yml'];

/// Individually-named files outside [_roots] — the build and packaging
/// surface. Eight of the ten files ADR 0009 missed lived here, precisely
/// because nobody thinks of the installer authoring or the Gemfile as
/// "source".
const _alsoCheck = [
  'Gemfile',
  'ios/fastlane/Appfile',
  'ios/fastlane/Fastfile',
  'ios/fastlane/Matchfile',
  'windows/installer/deskilo.wxs',
  'flutter_launcher_icons.yaml',
  'l10n.yaml',
  'analysis_options.yaml',
];

/// Files exempt from carrying a header, each for a stated reason.
/// This list may only ever SHRINK.
const _exempt = <String, String>{
  // Records the superseded MIT decision; quoting the old identifier is the
  // point of the document.
  'docs/decisions/0004-mit-license.md': 'documents the superseded licence',
};

bool _generated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.contains('/app_localizations');

void main() {
  test('every source file declares $_licence, and none declares anything else',
      () {
    final missing = <String>[];
    final wrong = <String>[];

    for (final root in _roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => _extensions.any(f.path.endsWith))
          .where((f) => !_generated(f.path))
          .where((f) => !_exempt.containsKey(f.path));

      _check(files, missing, wrong);
    }

    _check(
      _alsoCheck.map(File.new).where((f) => f.existsSync()),
      missing,
      wrong,
    );

    expect(
      wrong,
      isEmpty,
      reason: 'Declares a licence other than $_licence (ADR 0009):\n'
          '${wrong.join('\n')}',
    );
    expect(
      missing,
      isEmpty,
      reason: 'No $_spdx header in the first 8 lines:\n'
          '${missing.join('\n')}\n\n'
          'Add `SPDX-License-Identifier: $_licence` in the file\'s comment '
          'syntax (`//` for Dart, `#` for YAML/shell/Python, `--` for SQL).',
    );
  });
}

void _check(Iterable<File> files, List<String> missing, List<String> wrong) {
      for (final file in files) {
        // The header is a header: read the first lines, not the whole file,
        // so a stray mention deep in a fixture cannot satisfy the rule.
        final head = file.readAsLinesSync().take(8).join('\n');
        if (!head.contains(_spdx)) {
          missing.add(file.path);
        } else if (!head.contains('$_spdx: $_licence')) {
          final line = head
              .split('\n')
              .firstWhere((l) => l.contains(_spdx), orElse: () => '');
          wrong.add('${file.path}: ${line.trim()}');
    }
  }
}
