// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3475 -- the database job stands down for a Dart file only when that file is
// OUTSIDE the proven import closure of the Dart the job runs; every doubt runs
// the full job and names itself. This pins the proof: the directive reader,
// the invocation reader (the job's own commands, from quality.yml), the closure,
// the verdict, and -- over the real tree -- that a change to any file INSIDE the
// closure flips the verdict to required (a production mutant, not only the
// green path).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci_classify/classify.dart';
import '../../tool/ci_classify/closure.dart';

late Directory _tmp;

void _write(String path, String text) {
  File('${_tmp.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
}

/// A small repository: a topology test importing the app and a package, a tool,
/// and a quality.yml whose database job runs them.
void _repo({String job = _goodJob, bool tool = true}) {
  _write(
    '.github/workflows/quality.yml',
    'jobs:\n$job\n  report:\n    name: r\n',
  );
  _write(
    'test/topology/a_test.dart',
    "import 'package:deskilo/core/a.dart';\nimport 'package:deskilo_pkg/p.dart';\nimport '../helpers/h.dart';\n",
  );
  _write('test/helpers/h.dart', '');
  _write(
    'lib/core/a.dart',
    "import 'b.dart' if (dart.library.io) 'b_io.dart';\nexport 'c.dart';\npart 'a_part.dart';\n",
  );
  _write('lib/core/b.dart', '');
  _write('lib/core/b_io.dart', '');
  _write(
    'lib/core/c.dart',
    "import 'package:flutter/material.dart';\nimport 'dart:io';\n",
  );
  _write('lib/core/a_part.dart', "part of 'a.dart';\n");
  _write(
    'lib/features/money/domain/unrelated.dart',
    "import 'package:deskilo/core/b.dart';\n",
  );
  _write('packages/deskilo_pkg/lib/p.dart', '');
  _write('packages/deskilo_pkg/lib/q.dart', '');
  _write('packages/deskilo_pkg/pubspec.yaml', 'name: deskilo_pkg\n');
  if (tool) _write('tool/check.dart', "import 'package:deskilo_pkg/p.dart';\n");
  _write('scripts/run.sh', 'dart run tool/check.dart\n');
}

const _goodJob = '''  database:
    name: quality · database
    steps:
      - run: bash scripts/run.sh
      - run: |
          flutter test --no-pub test/topology/a_test.dart --reporter expanded''';

ChangeSet _pr(List<String> paths, {DbClosure Function()? closure}) => ChangeSet(
  paths: paths,
  baseKnown: true,
  event: 'pull_request',
  closure: closure,
);

Verdict _db(ChangeSet c) =>
    classify(c).firstWhere((v) => v.discipline == 'database');

void main() {
  setUp(() => _tmp = Directory.systemTemp.createTempSync('closure'));
  tearDown(() => _tmp.deleteSync(recursive: true));

  group('the directive reader', () {
    test(
      'reads imports, exports, parts and the branches of a conditional import',
      () {
        expect(
          directiveUris('''
// a comment: import 'no.dart';
library x;
import 'a.dart' if (dart.library.io) 'b.dart' if (dart.library.html) 'c.dart';
export "d.dart" show Foo;
import
    'multi/line.dart'
    as m;
part 'e.dart';
part of 'owner.dart';
/* import 'block.dart'; */
class X {}
'''),
          ['a.dart', 'b.dart', 'c.dart', 'd.dart', 'multi/line.dart', 'e.dart'],
        );
      },
    );

    test('an import inside a string after the header is not a directive', () {
      expect(
        directiveUris(
          "import 'real.dart';\nconst t = \"\"\"\nimport 'fake.dart';\n\"\"\";\n",
        ),
        ['real.dart'],
      );
    });
  });

  group('the invocation reader', () {
    test(
      'the database job\'s own commands name entry points under the roots',
      () {
        _repo();
        final inv = invokedEntryPoints(_tmp.path);
        expect(inv.problem, isNull);
        expect(inv.entries, {'test/topology/a_test.dart', 'tool/check.dart'});
      },
    );

    test('a directory, a variable, a package executable or a file outside the '
        'roots is a problem, never an ignored command', () {
      for (final bad in [
        '- run: flutter test test/topology',
        '- run: flutter test test/lint/x_test.dart',
        '- run: dart run build_runner build',
        r'- run: flutter test "${files[@]}"',
        '- run: dart run lib/main.dart',
      ]) {
        _repo(
          job:
              '  database:\n    name: quality · database\n    steps:\n      $bad',
        );
        final inv = invokedEntryPoints(_tmp.path);
        expect(inv.problem, isNotNull, reason: bad);
      }
    });

    test('a script the job runs that is not in the tree is a problem', () {
      _repo(
        job: '  database:\n    name: quality · database\n    steps:\n      - run: bash scripts/missing.sh',
      );
      expect(
        invokedEntryPoints(_tmp.path).problem,
        contains('scripts/missing.sh'),
      );
    });

    test('a file the job runs that is not in the tree is a problem', () {
      _repo(tool: false);
      expect(
        invokedEntryPoints(_tmp.path).problem,
        contains('tool/check.dart'),
      );
    });

    test('a workflow with no database job is a problem', () {
      _repo();
      _write('.github/workflows/quality.yml', 'jobs:\n  other:\n    name: x\n');
      expect(invokedEntryPoints(_tmp.path).problem, contains('database job'));
    });
  });

  group('the closure', () {
    test(
      'follows imports, exports, parts, conditional branches and packages',
      () {
        _repo();
        final c = databaseClosure(_tmp.path);
        expect(c.problem, isNull);
        expect(
          c.files,
          containsAll([
            'test/topology/a_test.dart',
            'test/helpers/h.dart',
            'lib/core/a.dart',
            'lib/core/b.dart',
            'lib/core/b_io.dart',
            'lib/core/c.dart',
            'lib/core/a_part.dart',
            'packages/deskilo_pkg/lib/p.dart',
            'tool/check.dart',
          ]),
        );
        expect(
          c.files,
          isNot(contains('lib/features/money/domain/unrelated.dart')),
        );
        expect(c.files, isNot(contains('packages/deskilo_pkg/lib/q.dart')));
      },
    );

    test('an import that is not a file of the repository is a problem', () {
      _repo();
      _write('lib/core/c.dart', "import 'gone.dart';\n");
      expect(
        databaseClosure(_tmp.path).problem,
        contains('lib/core/gone.dart'),
      );
    });

    test('a relative import that leaves the repository is a problem', () {
      _repo();
      _write('lib/core/c.dart', "import '../../../../etc/x.dart';\n");
      expect(databaseClosure(_tmp.path).problem, isNotNull);
    });

    test('an import of a non-Dart file is a problem', () {
      _repo();
      _write('lib/core/c.dart', "export 'data.json';\n");
      expect(databaseClosure(_tmp.path).problem, contains('not a Dart file'));
    });
  });

  group('the verdict', () {
    DbClosure Function() closure() {
      _repo();
      return () => databaseClosure(_tmp.path);
    }

    test('a file outside the closure stands the database job down, naming the proof', () {
      final v = _db(
        _pr([
          'lib/features/money/domain/unrelated.dart',
          'packages/deskilo_pkg/lib/q.dart',
        ], closure: closure()),
      );
      expect(v.required, isFalse);
      expect(v.reason, contains('outside the import closure'));
      expect(v.psv, endsWith('|v6'));
    });

    test('a file INSIDE the closure selects the job (the mutant flips the verdict)', () {
      for (final inside in [
        'lib/core/b.dart',
        'packages/deskilo_pkg/lib/p.dart',
        'lib/core/a_part.dart',
        'test/helpers/h.dart',
      ]) {
        final v = _db(_pr([inside], closure: closure()));
        expect(v.required, isTrue, reason: inside);
      }
    });

    test('one file inside among many outside selects the job', () {
      final v = _db(
        _pr([
          'lib/features/money/domain/unrelated.dart',
          'lib/core/c.dart',
          'packages/deskilo_pkg/lib/q.dart',
        ], closure: closure()),
      );
      expect(v.required, isTrue);
      expect(v.reason, contains('lib/core/c.dart'));
    });

    test(
      'a closure that cannot be proven runs the full job and names the doubt',
      () {
        _repo();
        _write('lib/core/c.dart', "import 'gone.dart';\n");
        final v = _db(
          _pr([
            'lib/features/money/domain/unrelated.dart',
          ], closure: () => databaseClosure(_tmp.path)),
        );
        expect(v.required, isTrue);
        expect(v.reason, contains('could not be proven'));
        expect(v.reason, contains('gone.dart'));
      },
    );

    test('no closure at all (a unit test of the path rules) never stands a Dart file down', () {
      expect(
        _db(_pr(['lib/features/money/domain/unrelated.dart'])).required,
        isTrue,
      );
    });

    test('SQL, a workflow, a script, the classifier, a lockfile, a non-Dart '
        'file and an unknown path still select, closure or not', () {
      for (final path in [
        'supabase/migrations/0999_x.sql',
        '.github/workflows/quality.yml',
        'scripts/run.sh',
        'tool/ci_classify/closure.dart',
        'pubspec.lock',
        'lib/features/money/domain/data.json',
        'packages/deskilo_pkg/pubspec.yaml',
        'assets/instance/contract.txt',
        'something/new.txt',
      ]) {
        final v = _db(
          _pr([
            path,
            'lib/features/money/domain/unrelated.dart',
          ], closure: closure()),
        );
        expect(v.required, isTrue, reason: path);
      }
    });

    test(
      'the hand-kept topology prefixes of v5 stay a floor under the proof',
      () {
        final v = _db(_pr(['lib/core/session/new.dart'], closure: closure()));
        expect(v.required, isTrue);
      },
    );

    test('docs only never asks for the closure', () {
      var asked = false;
      final v = _db(
        _pr(
          ['docs/x.md'],
          closure: () {
            asked = true;
            return const DbClosure({}, 'boom');
          },
        ),
      );
      expect(v.required, isFalse);
      expect(asked, isFalse);
    });
  });

  group('the real tree', () {
    final repo = Directory.current.path;

    test('the database job\'s Dart can be read and its closure proven', () {
      final inv = invokedEntryPoints(repo);
      expect(inv.problem, isNull, reason: '${inv.problem}');
      expect(
        inv.entries,
        containsAll([
          'test/topology/three_stacks_test.dart',
          'tool/mcp_coverage.dart',
          'tool/instance_lifecycle_check.dart',
        ]),
      );
      final c = databaseClosure(repo);
      expect(c.problem, isNull, reason: '${c.problem}');
      // the closure is small next to the app: that is what makes the proof worth having
      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length;
      final inLib = c.files.where((f) => f.startsWith('lib/')).length;
      expect(inLib, lessThan(lib ~/ 2));
    });

    test('a change to ANY file inside the closure selects the job; a change '
        'outside it (and outside the v5 path rules) stands it down', () {
      final c = databaseClosure(repo);
      expect(c.proven, isTrue);
      final sources = [
        for (final f in c.files)
          if (f.startsWith('lib/') ||
              f.startsWith('packages/') ||
              f.startsWith('test/'))
            f,
      ];
      expect(sources, isNotEmpty);
      for (final inside in sources) {
        final v = _db(_pr([inside], closure: () => c));
        expect(v.required, isTrue, reason: 'inside the closure: $inside');
      }
      // every Dart file of lib/ and packages/ is either in the closure or stood down
      final all = <String>[
        for (final root in ['lib', 'packages'])
          for (final f in Directory(
            root,
          ).listSync(recursive: true).whereType<File>())
            if (f.path.endsWith('.dart') && f.path.contains('/lib/') ||
                f.path.startsWith('lib/') && f.path.endsWith('.dart'))
              f.path,
      ];
      var outside = 0;
      for (final path in all) {
        final v = _db(_pr([path], closure: () => c));
        if (c.files.contains(path)) {
          expect(v.required, isTrue, reason: path);
        } else if (!v.required) {
          outside++;
          expect(
            v.reason,
            contains('independent of the database'),
            reason: path,
          );
        }
      }
      expect(
        outside,
        greaterThan(1000),
        reason: 'most of the app stands the job down',
      );
    });
  });
}
