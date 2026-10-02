// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Predicts the contract.txt lines a migration determines on its own, so a
// migration PR carries the right digest on its FIRST push instead of
// waiting for `quality · database` to fail and copying its artifact.
//
//   dart run tool/contract_predict.dart sql supabase/migrations/NNNN_x.sql
//     → prints the query to run on the reference (dev) project AFTER
//       applying the migration there, and what it cannot predict.
//   dart run tool/contract_predict.dart apply supabase/migrations/NNNN_x.sql result.json
//     → splices the query's result into assets/instance/contract.txt.
//
// Only what the file defines WHOLE is predicted: a function it creates or
// drops, the constraints and triggers of a table it creates. Their lines
// on dev equal the replay's (verified for 0330 and 0332). An anchored
// patch is refused: dev's long-patched bodies drift from the replay, so
// that routine's digest still comes from the CI artifact (exit 2).
import 'dart:io';

import 'contract_predict/predict.dart';

const _contract = 'assets/instance/contract.txt';
const _script = 'scripts/contract_check.sh';

// Dart ignores what `main` returns; the exit code is set here.
void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  if (args.length < 2 || !{'sql', 'apply'}.contains(args[0])) {
    stderr.writeln(
      'usage: contract_predict.dart sql <migration> | '
      'apply <migration> <result.json>',
    );
    return 64;
  }
  final scope = scan(File(args[1]).readAsStringSync());
  for (final u in scope.unsafe) {
    stderr.writeln('NOT PREDICTED: $u — its digest comes from the CI artifact');
  }
  if (args[0] == 'sql') {
    final sql = predictionSql(File(_script).readAsStringSync(), scope);
    stdout.writeln(
      sql.isEmpty ? '-- nothing this migration defines whole' : sql,
    );
  } else {
    if (args.length < 3) {
      stderr.writeln('apply needs the query result file');
      return 64;
    }
    final entries = parseEntries(File(args[2]).readAsStringSync());
    final file = File(_contract);
    file.writeAsStringSync(splice(file.readAsStringSync(), scope, entries));
    stdout.writeln(
      'spliced ${entries.length} entries for '
      '${scope.routines.length} routines, ${scope.tables.length} tables',
    );
  }
  return scope.unsafe.isEmpty ? 0 : 2;
}
