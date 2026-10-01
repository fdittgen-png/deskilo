// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the account layer in memory, for the suite and for Demo.
//
// Visibility is modelled with the rule the server applies (#1822), so a
// test can change a field as one account and read it back as another:
// an audience of "my spaces" is met when the two accounts share a space,
// "chosen spaces" when they share one of the chosen ones, "signed in"
// always, "nobody" never.
import 'package:deskilo/features/me/domain/me_repository.dart';
import 'package:deskilo/features/me/domain/my_spaces.dart';
import 'package:deskilo/features/me/domain/visibility.dart';

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

class FakeMeRepository implements MeRepository {
  FakeMeRepository({String Function()? currentUser, Map<String, FakeAccount>? accounts})
      : _currentUser = currentUser ?? (() => 'user-1'),
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
  Object? failure;

  /// Linked servers' spaces, by source; a source in [unavailable] throws.
  final Map<String, List<LinkedSpace>> linkedSpaces = {};
  final Set<String> unavailable = {};

  FakeAccount get _me => accounts.putIfAbsent(
      _currentUser(), () => FakeAccount(name: _currentUser()));

  @override
  Future<void> leaveSpace(String workspaceId) async {
    if (failure != null) throw failure!;
    left.add(workspaceId);
  }

  @override
  Future<MyVisibility> myVisibility() async =>
      _me.visibility.withAbout(_me.profession, _me.bio);

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
    _me.visibility = _me.visibility.withField(field, audience);
  }

  /// Whether [viewerSpaces] meets [choice].
  static bool _meets(FieldAudience choice, Set<String> owner,
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
                .any(choice.workspaces.contains);
    }
  }

  static AccountView _view(FakeAccount account, Set<String>? viewerSpaces,
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

  @override
  Future<List<LinkedSpace>> spacesOn(String source) async {
    if (unavailable.contains(source)) throw StateError('server unavailable');
    return linkedSpaces[source] ?? const [];
  }
}
