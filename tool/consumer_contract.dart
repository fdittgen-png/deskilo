// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3731 (K4) — the consumer contract of an app: what it calls on its
// installation, extracted from its source (tool/consumer_contract/extract.dart).
//
//   dart run tool/consumer_contract.dart                 # print a summary
//   dart run tool/consumer_contract.dart --write FILE    # write the contract
//   dart run tool/consumer_contract.dart --root DIR --source TAG --write FILE
//                                                        # a release's tree
//
// The release contracts live in contracts/consumer/releases/<tag>.json, each
// extracted from the tree of its tag. The database job checks every one of
// them against the schema after all migrations
// (scripts/consumer_contract_check.sh): a function the release calls still
// exists and accepts the parameters it sends, and a column it reads or writes
// is still there.
import 'dart:convert';
import 'dart:io';

import 'consumer_contract/extract.dart';

/// Extracts the contract of the tree at [root]: every Dart file under `lib/`
/// and `packages/*/lib/`, generated files included.
ConsumerContract extractTree(String root) {
  final contract = ConsumerContract();
  final migrations = Directory('$root/supabase/migrations');
  final server = ServerNames.fromMigrations(
    migrations.existsSync()
        ? migrations
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.sql'))
              .map((f) => f.readAsStringSync())
        : const [],
  );
  final dirs = [
    Directory('$root/lib'),
    ...Directory('$root/packages')
        .listSync()
        .whereType<Directory>()
        .map((d) => Directory('${d.path}/lib')),
  ].where((d) => d.existsSync());
  final files = [
    for (final d in dirs)
      ...d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final rel = f.path.substring(root.length + 1);
    extractInto(contract, rel, f.readAsStringSync(), server: server);
  }
  return contract;
}

void main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final root = option('--root') ?? '.';
  final out = option('--write');
  final source = option('--source');
  final contract = extractTree(Directory(root).absolute.path);
  final json = contract.toJson(source: source);
  if (contract.unresolved.isNotEmpty) {
    json['unresolved'] = contract.unresolved;
  }
  if (out != null) {
    File(out)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      );
  }
  stdout.writeln(
    '${contract.functions.length} functions, '
    '${contract.tables.length} tables, '
    '${contract.unresolved.length} calls with a name the syntax does not show',
  );
  for (final u in contract.unresolved) {
    stdout.writeln('  unresolved: $u');
  }
}
