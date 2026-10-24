// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2563 C1 — the workspaces my personal account names, by qualified
// reference (`<installation id>:<local id>`, #2561), as
// `my_personal_workspace_refs_v1()` answers them on my personal home.
//
// A reference is not a membership: it carries the relationship status
// only where the answering installation holds it itself (`local`), and
// says "verification unavailable" for a workspace on another installation
// until verified relationship facts exist (#2563 C2). It never carries a
// role or a permission. The decoding is strict (#2585): a malformed
// reference, status or freshness is a shape error, never an empty list.
import '../../../core/data/json_reader.dart';

/// `installation-uuid:workspace-uuid`, lower-case, as 0559 stamps it.
final RegExp _networkId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  r':[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// How the answering installation knows the relationship.
enum RefFreshness {
  /// Read from its own membership row, now.
  local,

  /// Another installation's workspace: no verified relationship yet.
  unavailable;

  static RefFreshness fromWire(JsonReader r) {
    final wire = r.string('freshness');
    return switch (wire) {
      'local' => local,
      'unavailable' => unavailable,
      _ => throw JsonShapeException(
        r.context,
        'freshness',
        'local|unavailable',
        wire,
      ),
    };
  }
}

/// The membership status as the workspace's row says it (0052), verbatim.
enum RefStatus {
  active,
  paused,
  pending,
  exited;

  static RefStatus? fromWire(JsonReader r) {
    final wire = r.stringOrNull('status');
    if (wire == null) return null;
    for (final s in values) {
      if (s.name == wire) return s;
    }
    throw JsonShapeException(r.context, 'status', 'RefStatus?', wire);
  }
}

/// One workspace my account names.
class PersonalWorkspaceRef {
  const PersonalWorkspaceRef({
    required this.networkId,
    required this.hostedHere,
    required this.freshness,
    this.label,
    this.status,
    this.isDefault = false,
    this.isFavorite = false,
    this.audienceFields = const [],
  });

  factory PersonalWorkspaceRef.fromJson(JsonReader r) {
    final networkId = r.string('network_id');
    if (!_networkId.hasMatch(networkId)) {
      throw JsonShapeException(
        r.context,
        'network_id',
        'network id',
        networkId,
      );
    }
    return PersonalWorkspaceRef(
      networkId: networkId,
      hostedHere: r.boolOr('hosted_here', fallback: false),
      freshness: RefFreshness.fromWire(r),
      label: r.stringOrNull('label'),
      status: RefStatus.fromWire(r),
      isDefault: r.boolOr('is_default', fallback: false),
      isFavorite: r.boolOr('is_favorite', fallback: false),
      audienceFields: r.strings('audience_fields'),
    );
  }

  final String networkId;

  /// The workspace lives on the installation that answered.
  final bool hostedHere;
  final RefFreshness freshness;

  /// The workspace's name, only where I may read it; null otherwise.
  final String? label;

  /// Null when the answering installation holds no relationship.
  final RefStatus? status;
  final bool isDefault;
  final bool isFavorite;

  /// The visibility fields whose chosen spaces name this workspace.
  final List<String> audienceFields;

  String get installationId => networkId.split(':').first;
  String get workspaceId => networkId.split(':').last;
}

/// My references, and the home that answered them.
class PersonalWorkspaceRefs {
  const PersonalWorkspaceRefs({
    required this.homeInstallationId,
    this.refs = const [],
  });

  static const PersonalWorkspaceRefs none = PersonalWorkspaceRefs(
    homeInstallationId: '',
  );

  factory PersonalWorkspaceRefs.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'my_personal_workspace_refs_v1');
    final home = r.objectOrNull('home');
    return PersonalWorkspaceRefs(
      homeInstallationId: home?.string('installation_id') ?? '',
      refs: r.objects('refs', PersonalWorkspaceRef.fromJson),
    );
  }

  final String homeInstallationId;
  final List<PersonalWorkspaceRef> refs;

  /// The references My spaces does not already show as a space of this
  /// installation: another installation's workspaces, and saved ones I
  /// hold no relationship with here.
  List<PersonalWorkspaceRef> get beyondLocalSpaces => [
    for (final ref in refs)
      if (!ref.hostedHere || ref.status == null) ref,
  ];
}
