// SPDX-License-Identifier: AGPL-3.0-or-later
import 'personal_export.dart';
import 'personal_workspace_refs.dart';
import 'public_person.dart';
import 'visibility.dart';

/// #1823 — the account layer's own calls on this server. Every one is about
/// the signed-in person; none reads or writes inside a workspace (#2563:
/// leaving one is `WorkspaceAccessRepository`'s, on that workspace's host).
/// The linked servers' calls are `LinkedMeRepository`'s.
abstract interface class MeRepository {
  /// `my_personal_workspace_refs_v1()` (#2563): the workspaces my account
  /// names by qualified reference, with no workspace needed here.
  Future<PersonalWorkspaceRefs> myWorkspaceRefs();

  /// `export_my_personal_data_v1()` (#2563, #2557 C2): the personal part of
  /// my data on my personal home, with no workspace. A typed refusal is
  /// [PersonalExportRefused]; anything else is the transport's failure.
  Future<PersonalExport> exportMyPersonalData();

  /// `my_visibility_network_v1()` (#2558): the chosen spaces by network
  /// reference, and the home that holds them.
  Future<MyVisibility> myVisibility();

  /// `set_visibility(field, audience, workspaces)`: today's writer, which
  /// takes LOCAL workspace ids of this home. `MeActions.choose` maps the
  /// references of this home to them and refuses any other.
  Future<void> setVisibility(VisibilityField field, FieldAudience audience);

  /// `set_my_about(profession, bio)`: the words only [VisibilityField.about]
  /// lets anyone read.
  Future<void> setAbout(String profession, String bio);

  /// `preview_my_account(as)`: what that audience would see of me.
  Future<AccountView> previewMyAccount(PreviewAudience audience);

  /// `visible_account(user)`: what I may see of another account.
  Future<AccountView> visibleAccount(String userId);

  /// `my_public_profile()`: whether I published a public profile (0389).
  Future<bool> myPublicProfile();

  /// `set_public_profile(publish)`: the explicit publish / withdraw step.
  Future<void> setPublicProfile({required bool publish});

  /// The public card (0390, `public_person_cards`): what anyone, signed in or not, may read of
  /// [userId] — null when the profile is not published (or unknown).
  Future<PublicPerson?> publicPerson(String userId);
}
