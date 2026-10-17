// SPDX-License-Identifier: AGPL-3.0-or-later
// Read-only Git discovery and content snapshots. Dirty membership is not a
// fingerprint: a generator may change a file which was already modified.
import 'dart:convert';
import 'dart:io';

typedef PreflightProcess = ProcessResult Function(
  String executable,
  List<String> arguments,
  String directory,
);

ProcessResult runPreflightProcess(
  String executable,
  List<String> arguments,
  String directory,
) => Process.runSync(
  executable,
  arguments,
  workingDirectory: directory,
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

class PreflightGit {
  PreflightGit(this.directory, this.execute);
  final String directory;
  final PreflightProcess execute;

  String text(List<String> arguments) {
    final result = execute('git', arguments, directory);
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return result.stdout as String;
  }

  Set<String> paths(List<String> arguments) =>
      text(arguments).split('\x00').where((p) => p.isNotEmpty).toSet();

  Set<String> changedPaths(String base) {
    if (base.isEmpty || base.startsWith('-')) {
      throw const FormatException('base must be a commit ref, not an option');
    }
    final sha = text(['rev-parse', '--verify', '$base^{commit}']).trim();
    return {
      ...paths(['diff', '--name-only', '-z', '--no-renames', sha, '--']),
      ...paths(['ls-files', '--others', '--exclude-standard', '-z']),
    };
  }

  Set<String> generatedPaths() =>
      paths(['ls-files', '-z', '--', '*.g.dart', '*.freezed.dart']);

  Map<String, String> snapshot() => {
    for (final path in changedPaths('HEAD')) path: _fingerprint(path),
  };

  String _fingerprint(String path) {
    final absolute = '$directory${Platform.pathSeparator}$path';
    final type = FileSystemEntity.typeSync(absolute, followLinks: false);
    if (type == FileSystemEntityType.notFound) return 'missing';
    // Do not read a symbolic link's external target.
    if (type == FileSystemEntityType.link) {
      return 'link:${Link(absolute).targetSync()}';
    }
    if (type != FileSystemEntityType.file) {
      throw FileSystemException('unsupported changed path type', path);
    }
    final mode = File(absolute).statSync().mode;
    // No -w: compute only, without writing Git objects or changing the index.
    final hash = text(['hash-object', '--no-filters', '--', path]).trim();
    return 'file:$mode:$hash';
  }
}

List<String> changedFingerprints(
  Map<String, String> before,
  Map<String, String> after,
) => ({
  ...before.keys,
  ...after.keys,
}.where((path) => before[path] != after[path]).toList()..sort());
