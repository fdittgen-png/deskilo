// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the shapes the generated public network catalogue
// (`public_network_operations.dart`) is written in. The catalogue grants
// nothing: SQL grants, RLS and the RPC bodies decide who may do what. These
// shapes say which surface an operation belongs to, what it binds to on
// the wire and which fields a reader may keep.

/// The three interfaces of #1847. Public is anonymous; participant is an
/// account acting for itself on the target; management authors what the
/// public surface shows and is never reachable anonymously.
enum PublicSurface { public, participant, management }

enum PublicPrincipal { anonymous, authenticated }

/// Who, beyond being signed in, the server requires.
enum PublicAuthority { none, self, owner }

enum PublicMutation { read, write, request }

enum PublicCardinality { many, zeroOrOne, one, none }

enum PublicFieldType {
  uuid,
  datetime,
  integer,
  integerList,
  stringList,
  text,
  boolean,
  enum_,
  currency,
  decimal,
  httpsUrl,
  httpsOrigin,
  object,
  array,
}

class PublicField {
  const PublicField(
    this.type, {
    this.required = false,
    this.maxLength,
    this.min,
    this.max,
    this.values = const [],
    this.schema,
    this.maxItems,
  });

  final PublicFieldType type;
  final bool required;
  final int? maxLength;
  final num? min, max;
  final List<String> values;

  /// The schema of an [PublicFieldType.object] value or of each element of
  /// an [PublicFieldType.array].
  final String? schema;
  final int? maxItems;
}

class PublicSchema {
  const PublicSchema(this.name, this.fields, {this.mustUnderstand});
  final String name;
  final Map<String, PublicField> fields;

  /// The key under which a server lists terms a reader must understand.
  final String? mustUnderstand;
}

class PublicOperationSpec {
  const PublicOperationSpec({
    required this.id,
    required this.surface,
    required this.principal,
    required this.authority,
    required this.mutation,
    required this.features,
    this.relation,
    this.rpc,
    this.select = const [],
    this.order = const [],
    this.pageSize,
    this.timeoutSeconds,
    this.params = const {},
    this.input = const {},
    this.output,
    required this.cardinality,
    this.versions = const [],
    this.requires = const [],
    this.baseline = false,
    this.unlabelled,
    this.revalidated = false,
  });

  /// The stable operation identifier.
  final String id;
  final PublicSurface surface;
  final PublicPrincipal principal;
  final PublicAuthority authority;
  final PublicMutation mutation;
  final List<String> features;

  /// The table or view a read binds to, or the RPC a call binds to.
  final String? relation, rpc;

  /// The columns a table read selects — its output allow-list on the wire.
  final List<String> select;
  final List<String> order;
  final int? pageSize, timeoutSeconds;

  /// RPC parameter → SQL type.
  final Map<String, String> params;

  /// RPC parameter → the schema its value must satisfy.
  final Map<String, String> input;

  /// The schema of each returned record.
  final String? output;
  final PublicCardinality cardinality;

  /// #1847 B — the versions of this operation this client implements.
  final List<int> versions;

  /// Capabilities a client must understand to perform it.
  final List<String> requires;

  /// Whether a server from before negotiation (no descriptor) implements
  /// version 1 of it.
  final bool baseline;

  /// The version an unlabelled request means: what a client from before
  /// negotiation, which sends no operation header, is taken to speak.
  final int? unlabelled;

  /// Whether the server revalidates the negotiated version.
  final bool revalidated;

  /// The `x-deskilo-operation` header value for [version].
  String operationHeader(int version) => '$id@$version';

  /// The PostgREST column list.
  String get selectClause => select.join(',');
}
