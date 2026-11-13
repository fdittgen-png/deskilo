// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3848 -- the Demo's code and seed data are a deferred library on the web:
// fetched when the Demo is entered, not with the app's first download. That
// holds only while nothing in the first download reaches them by an ordinary
// import. Outside `lib/core/demo/` a file may import only the Demo's light
// surface below (the entry flag, the link, the persona names, the entry
// screens, the environment widget, the loader seam); everything else of the
// Demo (session, fixture, scope, workspace, repositories, seeds) is reached
// through `demo_loader.dart`. And `demo_runtime.dart`, the deferred library's
// root, is imported only `deferred as`.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _demo = 'lib/core/demo/';

/// The Demo files the first download may import. Adding one is a decision:
/// it, and what it imports, then belongs to the first download.
const _lightSurface = {
  'demo_entry.dart',
  'demo_link.dart',
  'demo_loader.dart',
  'demo_persona.dart',
  'demo_reload_marker.dart',
  'demo_reload_marker_provider.dart',
  'demo_space_ids.dart',
  'presentation/demo_entry_screen.dart',
  'presentation/demo_entry_sheet.dart',
  'presentation/demo_environment.dart',
  'presentation/demo_setup_card.dart',
  'presentation/welcome_link_button.dart',
};

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+'([^']+)'([^;]*);''',
  multiLine: true,
);

/// The Demo files [source] (at [path]) imports, as paths under [_demo].
Iterable<String> _demoTargets(String path, String source) sync* {
  for (final m in _directive.allMatches(source)) {
    final uri = m.group(1)!;
    String? target;
    if (uri.startsWith('package:deskilo/')) {
      target = 'lib/${uri.substring('package:deskilo/'.length)}';
    } else if (!uri.contains(':')) {
      final parts = path.split('/')..removeLast();
      for (final seg in uri.split('/')) {
        if (seg == '..') {
          parts.removeLast();
        } else if (seg != '.') {
          parts.add(seg);
        }
      }
      target = parts.join('/');
    }
    if (target != null && target.startsWith(_demo)) {
      yield target.substring(_demo.length);
    }
  }
}

/// What [source] at [path] breaks.
List<String> seamViolations(String path, String source) {
  final found = <String>[];
  if (!path.startsWith(_demo)) {
    for (final t in _demoTargets(path, source)) {
      if (!_lightSurface.contains(t)) {
        found.add('$path imports $_demo$t; reach it through demo_loader.dart');
      }
    }
  }
  for (final m in _directive.allMatches(source)) {
    if (m.group(1)!.endsWith('demo_runtime.dart') &&
        !m.group(2)!.contains('deferred as')) {
      found.add('$path imports demo_runtime.dart without `deferred as`');
    }
  }
  return found;
}

void main() {
  test('nothing in the first download imports the Demo directly', () {
    final found = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      found.addAll(seamViolations(path, file.readAsStringSync()));
    }
    expect(found, isEmpty);
  });

  test(
    'the light surface exists and the deferred root is imported deferred',
    () {
      final demoFiles = handWrittenDartFiles(_demo)
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      for (final name in _lightSurface) {
        expect(
          demoFiles.any((p) => p.endsWith('$_demo$name')),
          isTrue,
          reason: '$name is listed but gone; delete it from the list',
        );
      }
    },
  );

  test('a planted direct import bites', () {
    expect(
      seamViolations(
        'lib/features/x/presentation/x.dart',
        "import '../../../core/demo/demo_session.dart';",
      ),
      isNotEmpty,
    );
    expect(
      seamViolations(
        'lib/features/x/x.dart',
        "import 'package:deskilo/core/demo/seed/demo_london_seed.dart';",
      ),
      isNotEmpty,
    );
    expect(
      seamViolations(
        'lib/core/demo/demo_loader.dart',
        "import 'demo_runtime.dart';",
      ),
      isNotEmpty,
    );
    expect(
      seamViolations(
        'lib/app/app.dart',
        "import '../core/demo/demo_loader.dart';",
      ),
      isEmpty,
    );
  });
}
