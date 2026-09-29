// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1829 — who answers for this installation. The database is shared by
// every workspace on it, so its owner (the platform owner of 0166) and the
// delegates the owner names are shown to everyone signed in. Only the
// owner sees the account ids needed to withdraw a delegation; the server
// decides that, this only reads what it sent.

/// What the signed-in person is for the installation.
enum InstanceRole { owner, delegate }

/// One person answerable for the installation.
class InstanceResponsible {
  const InstanceResponsible({
    required this.name,
    required this.email,
    this.userId,
    this.since,
  });

  final String name;
  final String email;

  /// Present only when the owner is looking: what a withdrawal names.
  final String? userId;
  final DateTime? since;

  static InstanceResponsible? tryParse(Object? json) {
    if (json is! Map) return null;
    final email = '${json['email'] ?? ''}'.trim();
    if (email.isEmpty) return null;
    final name = '${json['name'] ?? ''}'.trim();
    final id = json['user_id'];
    return InstanceResponsible(
      name: name.isEmpty ? email : name,
      email: email,
      userId: id is String && id.isNotEmpty ? id : null,
      since: DateTime.tryParse('${json['since'] ?? ''}'),
    );
  }
}

class InstanceResponsibles {
  const InstanceResponsibles({
    this.installationId = '',
    this.you,
    this.claimable = false,
    this.owners = const [],
    this.delegates = const [],
  });

  final String installationId;

  /// The caller's own role, or null for an ordinary member.
  final InstanceRole? you;

  /// A new instance without an owner, and the caller is its creator.
  final bool claimable;
  final List<InstanceResponsible> owners;
  final List<InstanceResponsible> delegates;

  bool get isOwner => you == InstanceRole.owner;
  bool get isOperator => you != null;

  /// A server older than 0314, or one that could not be read: nobody is
  /// named, and nothing can be changed.
  static const unavailable = InstanceResponsibles();

  /// Unknown or malformed answers fall to [unavailable]; entries without
  /// an e-mail address are dropped rather than shown blank.
  factory InstanceResponsibles.fromJson(Object? json) {
    if (json is! Map) return unavailable;
    List<InstanceResponsible> people(Object? v) => [
      for (final x in (v is List ? v : const []))
        ?InstanceResponsible.tryParse(x),
    ];
    return InstanceResponsibles(
      installationId: '${json['installation_id'] ?? ''}',
      you: switch (json['you']) {
        'owner' => InstanceRole.owner,
        'delegate' => InstanceRole.delegate,
        _ => null,
      },
      claimable: json['claimable'] == true,
      owners: people(json['owners']),
      delegates: people(json['delegates']),
    );
  }
}

/// What delegating to an e-mail address came to. The refusals say why, so
/// the screen can too.
enum DelegationOutcome {
  delegated,
  unchanged,
  noAccount,
  unconfirmed,
  alreadyOwner,
  unavailable;

  static DelegationOutcome fromJson(Object? json) {
    if (json is! Map) return unavailable;
    return switch (json['status']) {
      'delegated' => delegated,
      'unchanged' => unchanged,
      'refused' => switch (json['reason']) {
        'no_account' => noAccount,
        'unconfirmed' => unconfirmed,
        'already_owner' => alreadyOwner,
        _ => unavailable,
      },
      _ => unavailable,
    };
  }
}

abstract interface class InstanceRepository {
  Future<InstanceResponsibles> responsibles();
  Future<DelegationOutcome> delegate(String email);

  /// Whether a delegation was actually withdrawn.
  Future<bool> withdraw(String userId);

  /// Whether the caller became the owner of a new instance.
  Future<bool> claim();
}
