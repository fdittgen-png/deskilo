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
