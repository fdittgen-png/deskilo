// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2604: source enumeration belongs in lint_sources.dart. Detect executable
// Directory constructors without treating comments or fixture strings as walks;
// system-temp fixture children use the bounded shared helper.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The lint files that still build a `Directory(...)` themselves, each to be
/// moved to [handWrittenDartFiles], [sqlFiles] or [markdownFiles]. RATCHET:
/// remove a name when its file stops; never add one.
const _stillWalkingByHand = <String>{};

// Parse syntax so examples in string literals or comments do not count.
// All direct constructors, including named constructors, are refused. Temp
// fixture children use the bounded shared helper; source walks use shared APIs.
class _DirectoryCalls extends RecursiveAstVisitor<void> {
  bool found = false;
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if ((node.target == null && node.methodName.name == 'Directory') ||
        node.target?.toSource() == 'Directory') {
      found = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.toSource() == 'Directory') found = true;
    super.visitInstanceCreationExpression(node);
  }
}

bool _callsDirectory(String source) {
  final visitor = _DirectoryCalls();
  final parsed = parseString(content: source, throwIfDiagnostics: false);
  if (parsed.errors.isNotEmpty) return true;
  parsed.unit.accept(visitor);
  return visitor.found;
}

void main() {
  test('only the listed lint files build their own Directory walk', () {
    final calling = {
      for (final f in Directory('test/lint').listSync().whereType<File>())
        if (f.path.endsWith('.dart') &&
            !f.path.endsWith('/lint_sources.dart') &&
            !f.path.endsWith('/lint_sources_test.dart') &&
            _callsDirectory(f.readAsStringSync()))
          f.uri.pathSegments.last,
    };
    expect(
      calling.difference(_stillWalkingByHand),
      isEmpty,
      reason:
          'take the file list from lint_sources.dart '
          '(handWrittenDartFiles / sqlFiles / markdownFiles)',
    );
    expect(
      _stillWalkingByHand.difference(calling),
      isEmpty,
      reason:
          'these no longer walk by hand: delete them from the list '
          '(the ratchet only falls)',
    );
  });

  test('constructor detection ignores comments and strings, refuses walks', () {
    expect(
      _callsDirectory(
        "// Directory('lib')\nfinal text = \"Directory('lib')\";",
      ),
      isFalse,
    );
    expect(
      _callsDirectory(
        "void f() { Directory('lib').listSync(recursive: true); }",
      ),
      isTrue,
    );
    expect(
      _callsDirectory(
        "void f() { Directory.fromUri(Uri.directory('lib')).listSync(); }",
      ),
      isTrue,
    );
    expect(
      _callsDirectory(
        "void f() { Directory.systemTemp.createTempSync('fixture'); }",
      ),
      isFalse,
    );
  });

  group('the shared walks', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('lint-sources');
      for (final n in ['0002_b.sql', '0001_a.sql', 'note.md', 'x.txt']) {
        File('${dir.path}/$n').writeAsStringSync('-');
      }
      temporaryFixtureDirectory(dir, 'sub').createSync();
      File('${dir.path}/sub/0003_c.sql').writeAsStringSync('-');
      File('${dir.path}/sub/deep.md').writeAsStringSync('-');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    String name(File f) => f.uri.pathSegments.last;

    test('fixture children stay in system temp', () {
      expect(temporaryFixtureDirectory(dir, 'sub').existsSync(), isTrue);
      expect(
        () => temporaryFixtureDirectory(dir, '../lib'),
        throwsArgumentError,
      );
      expect(
        () => temporaryFixtureDirectory(Directory.current, 'lib'),
        throwsArgumentError,
      );
      Link('${dir.path}/escape').createSync(Directory.current.path);
      expect(
        () => temporaryFixtureDirectory(dir, 'escape'),
        throwsArgumentError,
      );
    });

    test('sqlFiles lists the .sql files in path order, flat by default', () {
      expect(sqlFiles(dir.path).map(name), ['0001_a.sql', '0002_b.sql']);
      expect(sqlFiles(dir.path, recursive: true).map(name), [
        '0001_a.sql',
        '0002_b.sql',
        '0003_c.sql',
      ]);
    });

    test('markdownFiles descends by default and ignores other kinds', () {
      expect(markdownFiles(dir.path).map(name), ['note.md', 'deep.md']);
      expect(markdownFiles(dir.path, recursive: false).map(name), ['note.md']);
    });
  });
}
