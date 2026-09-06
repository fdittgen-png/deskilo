// SPDX-License-Identifier: 0BSD
import 'dart:convert';

/// One migration file of the schema, in order.
typedef InstanceMigration = ({String name, String sql});

/// One edge function with its sources.
typedef InstanceFunction = ({
  String slug,
  bool verifyJwt,
  List<({String name, String content})> files,
});

/// Everything a new instance needs (#977): the schema as its migrations
/// in order and the edge functions with their sources, bundled by
/// `tool/build_instance.dart` into `assets/instance/bundle.json`.
class InstanceBundle {
  const InstanceBundle({required this.schema, required this.functions});

  final List<InstanceMigration> schema;
  final List<InstanceFunction> functions;

  /// The last migration's number — what an instance built from this
  /// bundle is at.
  String get schemaVersion =>
      schema.isEmpty ? '' : schema.last.name.split('_').first;

  static const assetPath = 'assets/instance/bundle.json';
}

InstanceBundle parseInstanceBundle(String json) {
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  return InstanceBundle(
    schema: [
      for (final m in decoded['schema'] as List)
        (name: (m as Map)['name'] as String, sql: m['sql'] as String),
    ],
    functions: [
      for (final f in decoded['functions'] as List)
        (
          slug: (f as Map)['slug'] as String,
          verifyJwt: f['verifyJwt'] as bool? ?? true,
          files: [
            for (final file in f['files'] as List)
              (
                name: (file as Map)['name'] as String,
                content: file['content'] as String,
              ),
          ],
        ),
    ],
  );
}
