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

@ProviderFor(myProfile)
final myProfileProvider = MyProfileProvider._();

/// My own profile row (#223); null while signed out. Invalidated by the
/// WhatsApp editor after a successful save.

final class MyProfileProvider
    extends
        $FunctionalProvider<AsyncValue<Profile?>, Profile?, FutureOr<Profile?>>
    with $FutureModifier<Profile?>, $FutureProvider<Profile?> {
  /// My own profile row (#223); null while signed out. Invalidated by the
  /// WhatsApp editor after a successful save.
  MyProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myProfileProvider',
        isAutoDispose: true,
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

String _$myProfileHash() => r'077a7aa878f6a7c0ba2ef698a526753a881da27b';

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

String _$memberAvatarHash() => r'd5ced693d6d3583cf5ecd7fd61c724042b8027ab';

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
