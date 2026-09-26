// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'template_field_registry.dart';

/// #1655 — the field registry as the database reads it.
///
/// `inspect_workspace_template` walks a template's payload and needs, per
/// field, the same disposition the client shows: portability, what an
/// absent value means, bounds, natural key, dependencies, bindings, the
/// process. A second hand-typed copy in SQL would drift the first time a
/// field was added, so `public.template_field_registry()` is GENERATED
/// from [templateFieldRegistry] — `dart run
/// tool/build_template_field_registry_sql.dart` — and
/// `template_field_registry_sql_test` requires the latest migration
/// defining it to carry exactly this text.
///
/// One record per line, keys in a fixed order, empty lists and nulls
/// left out: the literal is diffable by a person, and its md5 is the
/// registry revision the inspection reports.
String templateFieldRegistryJson() {
  final lines = <String>[];
  for (final s in templateFieldRegistry()) {
    final record = <String, Object?>{
      'id': s.id,
      'entity': s.entity,
      'type': s.type.name,
      'portability': _snake(s.portability.name),
      'absent': _snake(s.absent.name),
      if (s.naturalKey != null) 'key': s.naturalKey,
      if (s.values.isNotEmpty) 'values': s.values,
      if (s.min != null) 'min': s.min,
      if (s.max != null) 'max': s.max,
      if (s.dependsOn.isNotEmpty) 'depends_on': s.dependsOn,
      if (s.bindings.isNotEmpty) 'bindings': s.bindings,
      if (s.reason != null) 'reason': s.reason,
      'process': templateFieldProcess(s),
    };
    lines.add('    ${jsonEncode(record)}');
  }
  return '[\n${lines.join(',\n')}\n  ]';
}

String _snake(String camel) => camel.replaceAllMapped(
    RegExp('[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');

/// The whole `create or replace function` statement for a migration.
String templateFieldRegistrySql() => '''
create or replace function public.template_field_registry()
returns jsonb
language sql
immutable
set search_path = public
as \$registry\$
  select \$json\$${templateFieldRegistryJson()}\$json\$::jsonb
\$registry\$;''';
