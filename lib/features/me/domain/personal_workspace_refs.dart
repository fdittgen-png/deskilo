// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2563 C1 — the workspaces my personal account names, by qualified
// reference (`<installation id>:<local id>`, #2561), as
// `my_personal_workspace_refs_v1()` answers them on my personal home.
//
// A reference is not a membership: it carries the relationship status
// where the answering installation holds it itself (`local`) or holds a
// membership fact signed by the workspace's own installation (`verified`
// while in force, `stale` once it lapsed, #2563 C2), and says
// "verification unavailable" without one. It never carries a
// role or a permission. The decoding is strict (#2585): a malformed
// reference is a shape error, never an empty list. A status or freshness
// this build does not know (a newer server's) is the exception (#3884): it
// reads as no status / unavailable -- the readings that grant nothing -- and
// is traced; the reference stays in the list.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'package:meta/meta.dart';

import '../../../core/trace/trace_logger.dart';

/// `installation-uuid:workspace-uuid`, lower-case, as 0559 stamps it.
final RegExp _networkId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  r':[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// How the answering installation knows the relationship.
enum RefFreshness {
  /// Read from its own membership row, now.
  local,

  /// Another installation's workspace: a membership fact it signed, in
  /// force now.
  verified,

  /// Another installation's workspace: its last fact lapsed; the status
  /// is the last one it asserted and authorizes nothing.
  stale,

  /// Another installation's workspace: no verified relationship yet.
  unavailable;

  /// #3884 -- a freshness this build does not know reads as [unavailable]
  /// (no verified relationship: it authorizes nothing) and is traced.
  static RefFreshness fromWire(JsonReader r) {
    final wire = r.string('freshness');
    return switch (wire) {
      'local' => local,
      'verified' => verified,
      'stale' => stale,
      'unavailable' => unavailable,
      _ => _traced(r, 'freshness', wire, unavailable),
    };
  }
}

/// The membership status as the workspace's row says it (0052), verbatim.
enum RefStatus {
  active,
  paused,
  pending,
  exited;

  /// #3884 -- a status this build does not know reads as none (no
  /// relationship shown, nothing granted) and is traced.
  static RefStatus? fromWire(JsonReader r) {
    final wire = r.stringOrNull('status');
    if (wire == null) return null;
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return _traced<RefStatus?>(r, 'status', wire, null);
  }
}

/// The kinds of unknown value already traced: one entry per kind, not one
/// per row on every decode (#3884).
final Set<String> _tracedKinds = {};

/// Forgets which kinds were traced (tests).
@visibleForTesting
void resetTracedRefKinds() => _tracedKinds.clear();

T _traced<T>(JsonReader r, String field, String wire, T fallback) {
  if (_tracedKinds.add('$field|$wire')) {
    TraceLogger.instance.warn(
      'me',
      '${r.context}: unknown $field "$wire" -- read as ${fallback ?? 'none'}',
    );
  }
  return fallback;
}

/// One workspace my account names.
class PersonalWorkspaceRef {
  const PersonalWorkspaceRef({
    required this.networkId,
    required this.hostedHere,
    required this.freshness,
    this.label,
    this.status,
    this.statusUnknown = false,
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
    final status = RefStatus.fromWire(r);
    return PersonalWorkspaceRef(
      networkId: networkId,
      hostedHere: r.boolOr('hosted_here', fallback: false),
      freshness: RefFreshness.fromWire(r),
      label: r.stringOrNull('label'),
      status: status,
      // #3884 -- a status was sent but is not one this build knows: that is
      // "unknown", never "no relationship".
      statusUnknown: status == null && r.stringOrNull('status') != null,
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

  /// Null when the answering installation holds no relationship, or when
  /// it sent a status this build does not know ([statusUnknown]).
  final RefStatus? status;

  /// #3884 -- the installation sent a status this build does not know. The
  /// relationship exists: readers keep the reference (its bookings, its
  /// own-data export) and grant nothing that "no status" would not.
  final bool statusUnknown;

  /// The answering installation holds no relationship with the workspace.
  bool get holdsNoRelationshipHere => hostedHere && status == null && !statusUnknown;
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
