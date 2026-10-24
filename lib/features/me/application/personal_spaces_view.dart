// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — Me › My spaces, as a pure function of what was loaded: every
// workspace my account names (#2563 `my_personal_workspace_refs_v1`), each
// with its host, whether its membership is verified, and the one action
// its state allows. Nothing here reads a server; nothing here grants
// anything a reference does not already say.
import '../../workspace/domain/workspace.dart';
import '../domain/personal_workspace_refs.dart';

/// Where a space lives, as the personal home knows it.
enum PersonalSpaceHost {
  /// On the installation that answered: the person's own home.
  here,

  /// On another installation.
  elsewhere,
}

/// The one main action a space's state allows.
enum PersonalSpaceAction {
  /// An active membership of a space this server lists: walk in.
  open,

  /// A request not decided yet: its status, never operational access.
  requestStatus,

  /// History, an unverified relationship, or a saved space: no entry.
  none,
}

/// One space of My spaces.
class PersonalSpaceEntry {
  const PersonalSpaceEntry({required this.ref, this.local});

  final PersonalWorkspaceRef ref;

  /// The space of this server the reference names, when it is one of mine.
  final Workspace? local;

  PersonalSpaceHost get host =>
      ref.hostedHere ? PersonalSpaceHost.here : PersonalSpaceHost.elsewhere;

  /// The installation read the relationship from its own membership row.
  bool get verified =>
      ref.freshness == RefFreshness.local && ref.status != null;

  /// A development (test) space: its entry says so.
  bool get isTest => local?.isDevelopment ?? false;

  PersonalSpaceAction get action {
    if (!verified) return PersonalSpaceAction.none;
    return switch (ref.status) {
      RefStatus.active when local != null => PersonalSpaceAction.open,
      RefStatus.pending => PersonalSpaceAction.requestStatus,
      _ => PersonalSpaceAction.none,
    };
  }
}

/// My spaces from [refs], each matched to the space of this server it names
/// in [local] — by its qualified reference, so equal local ids on two
/// installations never meet. Favourites first, then the default, otherwise
/// in the order the home answered; filtered by [query] over the names that
/// may be read, the loaded records only.
List<PersonalSpaceEntry> personalSpaceEntries(
  PersonalWorkspaceRefs refs,
  List<Workspace> local, {
  String query = '',
}) {
  Workspace? localOf(PersonalWorkspaceRef ref) {
    if (!ref.hostedHere) return null;
    for (final w in local) {
      if (w.networkId.isNotEmpty
          ? w.networkId == ref.networkId
          : w.id == ref.workspaceId) {
        return w;
      }
    }
    return null;
  }

  final needle = query.trim().toLowerCase();
  final entries = [
    for (final ref in refs.refs)
      if (needle.isEmpty ||
          (ref.label ?? '').toLowerCase().contains(needle))
        PersonalSpaceEntry(ref: ref, local: localOf(ref)),
  ];
  int rank(PersonalSpaceEntry e) =>
      e.ref.isFavorite ? 0 : (e.ref.isDefault ? 1 : 2);
  // A stable sort: equal ranks keep the home's order.
  final indexed = entries.indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2) - rank(b.$2);
      return byRank != 0 ? byRank : a.$1 - b.$1;
    });
  return [for (final (_, e) in indexed) e];
}
