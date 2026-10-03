// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository>(value),
    );
  }
}

String _$profileRepositoryHash() => r'45c52cb7ca00235e652426023c450cae54c82031';

/// My own profile row (#223); null while signed out. Invalidated by the
/// WhatsApp editor after a successful save.
// The app router keeps listening to the consent gate for its lifetime.
/// #1823 — the writes My account makes about me (photo, invoice block).
/// #1914 — the notices that apply to the signed-in person in the current
/// space; [PrivacyNotices.none] signed out or when the server has none.

@ProviderFor(privacyNotices)
final privacyNoticesProvider = PrivacyNoticesProvider._();

/// My own profile row (#223); null while signed out. Invalidated by the
/// WhatsApp editor after a successful save.
// The app router keeps listening to the consent gate for its lifetime.
/// #1823 — the writes My account makes about me (photo, invoice block).
/// #1914 — the notices that apply to the signed-in person in the current
/// space; [PrivacyNotices.none] signed out or when the server has none.

final class PrivacyNoticesProvider
    extends
        $FunctionalProvider<
          AsyncValue<PrivacyNotices>,
          PrivacyNotices,
          FutureOr<PrivacyNotices>
        >
    with $FutureModifier<PrivacyNotices>, $FutureProvider<PrivacyNotices> {
  /// My own profile row (#223); null while signed out. Invalidated by the
  /// WhatsApp editor after a successful save.
  // The app router keeps listening to the consent gate for its lifetime.
  /// #1823 — the writes My account makes about me (photo, invoice block).
  /// #1914 — the notices that apply to the signed-in person in the current
  /// space; [PrivacyNotices.none] signed out or when the server has none.
  PrivacyNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyNoticesHash();

  @$internal
  @override
  $FutureProviderElement<PrivacyNotices> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PrivacyNotices> create(Ref ref) {
    return privacyNotices(ref);
  }
}

String _$privacyNoticesHash() => r'0f85f74ac0c512eb44ad7a1a5823b8061ba529a4';

/// #1915 — my rights requests, newest first.

@ProviderFor(myRightsRequests)
final myRightsRequestsProvider = MyRightsRequestsProvider._();

/// #1915 — my rights requests, newest first.

final class MyRightsRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RightsRequest>>,
          List<RightsRequest>,
          FutureOr<List<RightsRequest>>
        >
    with
        $FutureModifier<List<RightsRequest>>,
        $FutureProvider<List<RightsRequest>> {
  /// #1915 — my rights requests, newest first.
  MyRightsRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myRightsRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myRightsRequestsHash();

  @$internal
  @override
  $FutureProviderElement<List<RightsRequest>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RightsRequest>> create(Ref ref) {
    return myRightsRequests(ref);
  }
}

String _$myRightsRequestsHash() => r'e6118b4f767e1b029c863f5cde28f8cd119cbec9';

/// #1914 — the version the consent gate asks for: the installation
/// notice the SERVER publishes, so an operator's new notice is the one
/// acknowledged; the shipped version while it loads or on an older
/// server.

@ProviderFor(requiredPrivacyVersion)
final requiredPrivacyVersionProvider = RequiredPrivacyVersionProvider._();

/// #1914 — the version the consent gate asks for: the installation
/// notice the SERVER publishes, so an operator's new notice is the one
/// acknowledged; the shipped version while it loads or on an older
/// server.

final class RequiredPrivacyVersionProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// #1914 — the version the consent gate asks for: the installation
  /// notice the SERVER publishes, so an operator's new notice is the one
  /// acknowledged; the shipped version while it loads or on an older
  /// server.
  RequiredPrivacyVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requiredPrivacyVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$requiredPrivacyVersionHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return requiredPrivacyVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$requiredPrivacyVersionHash() =>
    r'cb7a6ad0fa28ee3307088c5ab848fb91c4944295';

@ProviderFor(myProfileEdits)
final myProfileEditsProvider = MyProfileEditsProvider._();

final class MyProfileEditsProvider
    extends $FunctionalProvider<MyProfileEdits, MyProfileEdits, MyProfileEdits>
    with $Provider<MyProfileEdits> {
  MyProfileEditsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myProfileEditsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myProfileEditsHash();

  @$internal
  @override
  $ProviderElement<MyProfileEdits> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MyProfileEdits create(Ref ref) {
    return myProfileEdits(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MyProfileEdits value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MyProfileEdits>(value),
    );
  }
}

String _$myProfileEditsHash() => r'23f2fa00c8d847a370f3ba4d9148a6e580993063';

@ProviderFor(myProfile)
final myProfileProvider = MyProfileProvider._();

final class MyProfileProvider
    extends
        $FunctionalProvider<AsyncValue<Profile?>, Profile?, FutureOr<Profile?>>
    with $FutureModifier<Profile?>, $FutureProvider<Profile?> {
  MyProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myProfileHash();

  @$internal
  @override
  $FutureProviderElement<Profile?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Profile?> create(Ref ref) {
    return myProfile(ref);
  }
}

String _$myProfileHash() => r'f1626a715fd49460deb74f0c467f4afaf014d7ea';

/// Bytes of [userId]'s profile photo (0038), or null when they have none.
/// Kept alive so a member's avatar is fetched once and reused across the
/// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
/// before watching this so the download only runs for members who set one.

@ProviderFor(memberAvatar)
final memberAvatarProvider = MemberAvatarFamily._();

/// Bytes of [userId]'s profile photo (0038), or null when they have none.
/// Kept alive so a member's avatar is fetched once and reused across the
/// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
/// before watching this so the download only runs for members who set one.

final class MemberAvatarProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// Bytes of [userId]'s profile photo (0038), or null when they have none.
  /// Kept alive so a member's avatar is fetched once and reused across the
  /// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
  /// before watching this so the download only runs for members who set one.
  MemberAvatarProvider._({
    required MemberAvatarFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberAvatarProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberAvatarHash();

  @override
  String toString() {
    return r'memberAvatarProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return memberAvatar(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberAvatarProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberAvatarHash() => r'06464f3d85a99036adaa4e50f40682d5779f9260';

/// Bytes of [userId]'s profile photo (0038), or null when they have none.
/// Kept alive so a member's avatar is fetched once and reused across the
/// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
/// before watching this so the download only runs for members who set one.

final class MemberAvatarFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, String> {
  MemberAvatarFamily._()
    : super(
        retry: null,
        name: r'memberAvatarProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Bytes of [userId]'s profile photo (0038), or null when they have none.
  /// Kept alive so a member's avatar is fetched once and reused across the
  /// directory, calendar and sheets; callers gate on `Profile.hasAvatar`
  /// before watching this so the download only runs for members who set one.

  MemberAvatarProvider call(String userId) =>
      MemberAvatarProvider._(argument: userId, from: this);

  @override
  String toString() => r'memberAvatarProvider';
}

/// #793 — the monogram each member's avatar shows, keyed by auth user id
/// (what [MemberAvatar] holds) rather than member id.
///
/// Computed for the whole workspace at once, because uniqueness is a
/// property of the SET: no row can pick its own letters without knowing
/// what the others took. Empty while the feature is off or the member
/// list has not arrived — the avatar then falls back to the single first
/// letter it always drew, which is also the right answer for a face the
/// member list does not cover (a former member on an old message).

@ProviderFor(memberMonograms)
final memberMonogramsProvider = MemberMonogramsProvider._();

/// #793 — the monogram each member's avatar shows, keyed by auth user id
/// (what [MemberAvatar] holds) rather than member id.
///
/// Computed for the whole workspace at once, because uniqueness is a
/// property of the SET: no row can pick its own letters without knowing
/// what the others took. Empty while the feature is off or the member
/// list has not arrived — the avatar then falls back to the single first
/// letter it always drew, which is also the right answer for a face the
/// member list does not cover (a former member on an old message).

final class MemberMonogramsProvider
    extends
        $FunctionalProvider<
          Map<String, String>,
          Map<String, String>,
          Map<String, String>
        >
    with $Provider<Map<String, String>> {
  /// #793 — the monogram each member's avatar shows, keyed by auth user id
  /// (what [MemberAvatar] holds) rather than member id.
  ///
  /// Computed for the whole workspace at once, because uniqueness is a
  /// property of the SET: no row can pick its own letters without knowing
  /// what the others took. Empty while the feature is off or the member
  /// list has not arrived — the avatar then falls back to the single first
  /// letter it always drew, which is also the right answer for a face the
  /// member list does not cover (a former member on an old message).
  MemberMonogramsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberMonogramsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberMonogramsHash();

  @$internal
  @override
  $ProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, String> create(Ref ref) {
    return memberMonograms(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$memberMonogramsHash() => r'8bb0b2fc1c4989ac46c2371d0718f664105b4f5a';

/// One account/workspace context for private personal preferences (#1791).

@ProviderFor(personalPreferenceContext)
final personalPreferenceContextProvider = PersonalPreferenceContextProvider._();

/// One account/workspace context for private personal preferences (#1791).

final class PersonalPreferenceContextProvider
    extends
        $FunctionalProvider<
          ({String? account, String? workspace}),
          ({String? account, String? workspace}),
          ({String? account, String? workspace})
        >
    with $Provider<({String? account, String? workspace})> {
  /// One account/workspace context for private personal preferences (#1791).
  PersonalPreferenceContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalPreferenceContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalPreferenceContextHash();

  @$internal
  @override
  $ProviderElement<({String? account, String? workspace})> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ({String? account, String? workspace}) create(Ref ref) {
    return personalPreferenceContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({String? account, String? workspace}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({String? account, String? workspace})>(value),
    );
  }
}

String _$personalPreferenceContextHash() =>
    r'36f10129630c6d82633fd23aabf2b819d219c091';
