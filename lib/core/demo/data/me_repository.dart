// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the account layer in memory, for the suite and for Demo.
//
// Visibility is modelled with the rule the server applies (#1822), so a
// test can change a field as one account and read it back as another:
// an audience of "my spaces" is met when the two accounts share a space,
// "chosen spaces" when they share one of the chosen ones, "signed in"
// always, "nobody" never.
import 'package:deskilo/features/me/domain/linked_me_repository.dart';
import 'package:deskilo/features/me/domain/me_repository.dart';
import 'package:deskilo/features/me/domain/my_spaces.dart';
import 'package:deskilo/features/me/domain/personal_export.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/domain/public_person.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:deskilo/features/me/domain/workspace_access_repository.dart';

/// One account's public facts, before any audience is applied.
class FakeAccount {
  FakeAccount({
    required this.name,
    this.profession = '',
    this.bio = '',
    this.whatsapp = '',
    this.email = '',
    this.presence = '',
    this.spaces = const {},
  });

  final String name, whatsapp, email, presence;
  String profession, bio;

  /// The spaces this account is an active member of.
  final Set<String> spaces;
  MyVisibility visibility = MyVisibility.defaults;
}

/// The installation id the fake personal home answers with.
const _fakeHomeInstallationId = '00000000-0000-4000-8000-0000000000e1';

/// #2563 — also the [WorkspaceAccessRepository]: one in-memory account.
/// #2558 — the personal home names chosen spaces by network reference
/// (`<home>:<local id>`) and its writer takes local ids, as the server's do.
class FakeMeRepository implements MeRepository, WorkspaceAccessRepository {
  FakeMeRepository({
    String Function()? currentUser,
    Map<String, FakeAccount>? accounts,
    this.homeInstallationId = _fakeHomeInstallationId,
    Map<String, String>? spaceLabels,
  })  : _currentUser = currentUser ?? (() => 'user-1'),
        spaceLabels = spaceLabels ?? {},
        accounts = accounts ??
            {
              'user-1': FakeAccount(
                name: 'Test User',
                profession: 'Designer',
                email: 'test@example.com',
                spaces: {'ws-1'},
              ),
            };

  final String Function() _currentUser;
  final Map<String, FakeAccount> accounts;

  /// Spaces left through [leaveSpace], in call order.
  final List<String> left = [];

  /// When set, [leaveSpace] and [setVisibility] throw it.
  Exception? failure;

  /// #2558 — when set, [myVisibility] throws it: the personal home cannot
  /// read the saved settings. Clearing it lets a retry succeed.
  Exception? readFailure;

  /// How many times [myVisibility] was asked.
  int visibilityReads = 0;

  FakeAccount get _me => accounts.putIfAbsent(
      _currentUser(), () => FakeAccount(name: _currentUser()));

  /// The installation this personal home is.
  final String homeInstallationId;

  /// The names of this home's spaces, by local id; a space of my account
  /// that has none here is listed unnamed.
  final Map<String, String> spaceLabels;

  /// The network reference of the local space [localId] of this home.
  String refOf(String localId) => '$homeInstallationId:$localId';

  /// What [myWorkspaceRefs] answers; when [refsFailure] is set it throws.
  /// Null derives it: every space of my account and of [spaceLabels], hosted
  /// here, active, read locally.
  PersonalWorkspaceRefs? workspaceRefs;
  Exception? refsFailure;

  /// How many times [myWorkspaceRefs] was asked.
  int refsReads = 0;

  @override
  Future<PersonalWorkspaceRefs> myWorkspaceRefs() async {
    refsReads++;
    if (refsFailure != null) throw refsFailure!;
    return workspaceRefs ??
        PersonalWorkspaceRefs(
          homeInstallationId: homeInstallationId,
          refs: [
            for (final id in ({..._me.spaces, ...spaceLabels.keys}.toList()
              ..sort()))
              PersonalWorkspaceRef(
                networkId: refOf(id),
                hostedHere: true,
                freshness: RefFreshness.local,
                status: RefStatus.active,
                label: spaceLabels[id],
              ),
          ],
        );
  }

  /// #2557 C2 — what [exportMyPersonalData] answers, decoded as the home's
  /// answer would be; when [exportFailure] is set it throws. How many times
  /// it was asked is [exportReads].
  Map<String, Object?> personalExport = {
    'format': personalExportFormat,
    'version': personalExportVersion,
    'exported_at': '2026-01-15T09:00:00Z',
    'profile': {'id': 'user-1', 'full_name': 'Test User'},
    'account_conversations': const [],
    'account_messages': const [],
    'account_group_messages': const [],
    'workspace_refs': const [],
  };
  Exception? exportFailure;
  int exportReads = 0;

  @override
  Future<PersonalExport> exportMyPersonalData() async {
    exportReads++;
    if (exportFailure != null) throw exportFailure!;
    return PersonalExport.decode(personalExport);
  }

  @override
  Future<void> leaveSpace(String workspaceId) async {
    if (failure != null) throw failure!;
    left.add(workspaceId);
  }

  @override
  Future<MyVisibility> myVisibility() async {
    visibilityReads++;
    if (readFailure != null) throw readFailure!;
    return _me.visibility
        .withAbout(_me.profession, _me.bio)
        .withHome(homeInstallationId);
  }

  @override
  Future<void> setAbout(String profession, String bio) async {
    if (failure != null) throw failure!;
    _me
      ..profession = profession
      ..bio = bio;
  }

  @override
  Future<void> setVisibility(
    VisibilityField field,
    FieldAudience audience,
  ) async {
    if (failure != null) throw failure!;
    if (audience.incomplete) throw ArgumentError('choose at least one space');
    // 0392 — the server's cap, mirrored.
    if (!field.allowedAudiences.contains(audience.audience)) {
      throw ArgumentError('this field never goes beyond your spaces');
    }
    // `set_visibility` takes local ids; the reader answers references.
    if (audience.workspaces.any((id) => id.contains(':'))) {
      throw ArgumentError('set_visibility takes local ids');
    }
    _me.visibility = _me.visibility.withField(
      field,
      FieldAudience(
          audience.audience, {for (final id in audience.workspaces) refOf(id)}),
    );
  }

  /// The local ids [refs] name on this home; another home's are no space here.
  Set<String> _local(Set<String> refs) => {
        for (final ref in refs)
          if (ref.startsWith('$homeInstallationId:'))
            ref.substring(homeInstallationId.length + 1),
      };

  /// Whether [viewerSpaces] meets [choice].
  bool _meets(FieldAudience choice, Set<String> owner,
      Set<String>? viewerSpaces, {required bool signedIn}) {
    switch (choice.audience) {
      case VisibilityAudience.nobody:
        return false;
      case VisibilityAudience.signedIn:
        return signedIn;
      case VisibilityAudience.mySpaces:
        return viewerSpaces != null && viewerSpaces.intersection(owner).isNotEmpty;
      case VisibilityAudience.chosenSpaces:
        return viewerSpaces != null &&
            viewerSpaces
                .intersection(owner)
                .any(_local(choice.workspaces).contains);
    }
  }

  AccountView _view(FakeAccount account, Set<String>? viewerSpaces,
      {required bool signedIn, bool owner = false}) {
    bool shows(VisibilityField field) => owner || _meets(
        account.visibility.of(field), account.spaces, viewerSpaces,
        signedIn: signedIn);
    String? keep(VisibilityField field, String value) =>
        shows(field) && value.isNotEmpty ? value : null;
    return AccountView(
      presenceShared: shows(VisibilityField.presence),
      name: shows(VisibilityField.identity) ? account.name : null,
      profession: keep(VisibilityField.about, account.profession),
      bio: keep(VisibilityField.about, account.bio),
      whatsapp: keep(VisibilityField.contactChannels, account.whatsapp),
      email: keep(VisibilityField.contactChannels, account.email),
      presence: keep(VisibilityField.presence, account.presence),
      canMessage: shows(VisibilityField.reachability),
    );
  }

  @override
  Future<AccountView> previewMyAccount(PreviewAudience audience) async =>
      switch (audience) {
        // Somebody in one of my spaces: every space I am in is shared.
        PreviewAudience.mySpaces => _view(_me, _me.spaces, signedIn: true),
        // A stranger with an account: no space in common.
        PreviewAudience.signedIn => _view(_me, const {}, signedIn: true),
        // Only me: everything, as I see myself.
        PreviewAudience.nobody => _view(_me, null, signedIn: true, owner: true),
      };

  @override
  Future<AccountView> visibleAccount(String userId) async {
    final target = accounts[userId];
    if (target == null) return const AccountView();
    return _view(target, _me.spaces, signedIn: true);
  }

  /// The accounts that published a public profile (0389).
  final Set<String> published = {};

  @override
  Future<bool> myPublicProfile() async => published.contains(_currentUser());

  @override
  Future<void> setPublicProfile({required bool publish}) async {
    if (failure != null) throw failure!;
    publish ? published.add(_currentUser()) : published.remove(_currentUser());
  }

  @override
  Future<PublicPerson?> publicPerson(String userId) async {
    final account = accounts[userId];
    if (account == null || !published.contains(userId)) return null;
    return PublicPerson(
      name: account.name,
      profession: account.profession,
      bio: account.bio,
    );
  }
}

/// #2211 — the linked servers' side of the account layer in memory: each
/// server's spaces and my visibility there, by source.
class FakeLinkedMeRepository implements LinkedMeRepository {
  /// Linked servers' spaces, by source; a source in [unavailable] throws.
  final Map<String, List<LinkedSpace>> linkedSpaces = {};
  final Set<String> unavailable = {};

  /// My visibility on each linked server, by source.
  final Map<String, MyVisibility> linkedVisibility = {};

  @override
  Future<List<LinkedSpace>> spaces(String source) async {
    if (unavailable.contains(source)) throw StateError('server unavailable');
    return linkedSpaces[source] ?? const [];
  }

  @override
  Future<MyVisibility> visibility(String source) async {
    if (unavailable.contains(source)) throw StateError('server unavailable');
    return linkedVisibility[source] ?? MyVisibility.defaults;
  }

  @override
  Future<void> setVisibility(
    String source,
    VisibilityField field,
    FieldAudience audience,
  ) async {
    if (unavailable.contains(source)) throw StateError('server unavailable');
    // 0392 — the same cap as at home; chosen spaces are not offered there.
    if (!field.allowedAudiences.contains(audience.audience) ||
        audience.audience == VisibilityAudience.chosenSpaces) {
      throw ArgumentError('not an audience for ${field.wire} there');
    }
    linkedVisibility[source] =
        (linkedVisibility[source] ?? MyVisibility.defaults)
            .withField(field, audience);
  }
}
