// SPDX-License-Identifier: 0BSD
//
// #914 — who may administer one managed profile.
//
// An admin-managed profile holds a real person's identity before that
// person has an account. Until now ANY admin of the workspace could
// read it, edit it and hand it over; for a space where several people
// hold the role, that is more exposure than the person agreed to.
//
// The rule names ROLES, PEOPLE, or both. Empty is the rule nobody has
// narrowed — owner and admin, exactly what #887 shipped — so nothing
// changes until someone narrows it. `can_manage_managed_profile` (0161)
// is the same rule in SQL and is what actually decides; this mirror
// exists so the app can show and edit it, never so it can grant.
class ManagedAccess {
  const ManagedAccess({
    this.roles = const {},
    this.memberIds = const {},
    this.narrowed = false,
  });

  /// `owner` and/or `admin`. Meaningless while [narrowed] is false.
  final Set<String> roles;

  /// Members named individually, whatever their role.
  final Set<String> memberIds;

  /// Whether anyone has stated a rule at all. False = the default.
  final bool narrowed;

  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';

  /// The default rule, in words: every owner and every admin.
  static const ManagedAccess unnarrowed = ManagedAccess();

  bool get isDefault => !narrowed;

  bool hasRole(String role) => narrowed
      ? roles.contains(role)
      : (role == roleOwner || role == roleAdmin);

  ManagedAccess withRole(String role, bool on) => ManagedAccess(
        roles: {
          ...narrowed ? roles : const {roleOwner, roleAdmin},
          if (on) role,
        }..removeWhere((r) => !on && r == role),
        memberIds: memberIds,
        narrowed: true,
      );

  ManagedAccess withMember(String memberId, bool on) => ManagedAccess(
        roles: narrowed ? roles : const {roleOwner, roleAdmin},
        memberIds: {...memberIds, if (on) memberId}
          ..removeWhere((m) => !on && m == memberId),
        narrowed: true,
      );

  /// Back to "every owner and every admin".
  ManagedAccess get reset => ManagedAccess.unnarrowed;

  factory ManagedAccess.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    return ManagedAccess(
      roles: roles is List ? {for (final r in roles) '$r'} : const {},
      memberIds: json['members'] is List
          ? {for (final m in json['members'] as List) '$m'}
          : const {},
      // A rule exists the moment either key is present: an EMPTY roles
      // list is a statement ("no role, only these people"), not silence.
      narrowed: roles is List || json['members'] is List,
    );
  }

  Map<String, dynamic> toJson() => narrowed
      ? {'roles': roles.toList()..sort(), 'members': memberIds.toList()..sort()}
      : const <String, dynamic>{};

  @override
  bool operator ==(Object other) =>
      other is ManagedAccess &&
      other.narrowed == narrowed &&
      _same(other.roles, roles) &&
      _same(other.memberIds, memberIds);

  @override
  int get hashCode => Object.hash(
        narrowed,
        Object.hashAllUnordered(roles),
        Object.hashAllUnordered(memberIds),
      );

  static bool _same(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
