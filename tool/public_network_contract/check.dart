// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the public network catalogue against what the database actually
// grants. Pure: it takes the catalogue, the effective SQL contract
// (assets/instance/contract.txt, written from the CI replay) and the
// migration texts, and names every disagreement. A catalogue that claims a
// column anonymous readers are not granted, a management or participant
// RPC executable by `anon`, or an input key the server would not accept is
// a problem, not a document.

/// Every disagreement between [contract] and the SQL, as sentences.
List<String> publicNetworkBindingProblems(
  Map<String, dynamic> contract, {
  required List<String> routines,
  required Map<String, String> migrations,
}) {
  final problems = <String>[];
  final names = migrations.keys.toList()..sort();
  String? latest(RegExp pattern) {
    for (final name in names.reversed) {
      final m = pattern.firstMatch(migrations[name]!);
      if (m != null) return m.group(0);
    }
    return null;
  }

  final schemas = Map<String, dynamic>.from(contract['schemas'] as Map);
  for (final raw in contract['operations'] as List) {
    final op = Map<String, dynamic>.from(raw as Map);
    final id = op['id'];
    final b = Map<String, dynamic>.from(op['binding'] as Map);
    final surface = op['surface'];
    final anonymous = op['principal'] == 'anonymous';
    if ((surface == 'public') != anonymous) {
      problems.add('$id: only the public surface is anonymous');
    }
    if (surface == 'public' && op['mutation'] != 'read') {
      problems.add('$id: a public operation is a read');
    }
    if (surface == 'management' && op['authority'] != 'owner') {
      problems.add('$id: management requires the owner');
    }
    if (b['kind'] == 'rpc') {
      final rpc = b['rpc'];
      final lines = routines
          .where((l) => l.startsWith('routine public.$rpc('))
          .toList();
      if (lines.length != 1) {
        problems.add(
          '$id: $rpc is not exactly one routine in the effective contract',
        );
        continue;
      }
      final line = lines.single;
      final exec =
          RegExp(r'exec:([a-z_,]+)').firstMatch(line)?.group(1)?.split(',') ??
          const [];
      if (!exec.contains('authenticated')) {
        problems.add('$id: $rpc is not executable by authenticated');
      }
      if (anonymous && !exec.contains('anon')) {
        problems.add('$id: $rpc is not executable by anon');
      }
      if (!anonymous && exec.contains('anon')) {
        problems.add('$id: $rpc is executable by anon');
      }
      for (final e in Map<String, dynamic>.from(b['params'] as Map).entries) {
        if (!line.contains('${e.key} ${e.value}')) {
          problems.add('$id: $rpc has no parameter ${e.key} ${e.value}');
        }
      }
    } else {
      final relation = b['relation'];
      final grant = latest(
        RegExp(
          'grant select\\(([a-z_,]+)\\) on public\\.$relation to anon,authenticated;',
        ),
      );
      if (grant == null) {
        problems.add('$id: no column grant to anon on $relation');
        continue;
      }
      final granted = RegExp(r'select\(([a-z_,]+)\)')
          .firstMatch(grant)!
          .group(1)!
          .split(',')
          .toSet();
      for (final c in b['select'] as List) {
        if (!granted.contains(c)) {
          problems.add('$id: $relation.$c is not granted to anon');
        }
      }
      if (latest(
            RegExp(
              'grant (select|all)[^(;]* on (table )?public\\.$relation to [^;]*anon',
            ),
          ) !=
          null) {
        problems.add('$id: $relation has a whole-table grant to anon');
      }
    }
    for (final e in Map<String, dynamic>.from(
      op['input'] as Map? ?? const {},
    ).entries) {
      final keys = (Map<String, dynamic>.from(
        (schemas[e.value] as Map)['fields'] as Map,
      )).keys.toSet();
      final body = latest(
        RegExp(
          'function public\\.${b['rpc']}\\([\\s\\S]*?k not in \\(([^)]*)\\)',
        ),
      );
      if (body == null) {
        problems.add('$id: no key allow-list found in ${b['rpc']}');
        continue;
      }
      final sqlKeys = RegExp(r"'([a-z_]+)'")
          .allMatches(
            RegExp(r'k not in \(([^)]*)\)').firstMatch(body)!.group(1)!,
          )
          .map((m) => m.group(1)!)
          .toSet();
      if (sqlKeys.difference(keys).isNotEmpty ||
          keys.difference(sqlKeys).isNotEmpty) {
        problems.add(
          '$id: ${e.value} lists ${keys.toList()..sort()} but '
          '${b['rpc']} accepts ${sqlKeys.toList()..sort()}',
        );
      }
    }
  }
  return problems;
}
