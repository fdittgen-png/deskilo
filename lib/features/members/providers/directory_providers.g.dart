// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).

@ProviderFor(memberProfiles)
final memberProfilesProvider = MemberProfilesProvider._();

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).

final class MemberProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Profile>>,
          Map<String, Profile>,
          FutureOr<Map<String, Profile>>
        >
    with
        $FutureModifier<Map<String, Profile>>,
        $FutureProvider<Map<String, Profile>> {
  /// user id → profile for the active workspace's members (#224): the
  /// directory derives statuses from `last_seen_at` and shows the WhatsApp
  /// button for shared numbers. RLS already trims the read to people
  /// sharing a workspace with the caller (#223).
  MemberProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberProfilesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Profile>> create(Ref ref) {
    return memberProfiles(ref);
  }
}

String _$memberProfilesHash() => r'03616ed6e5888fd99cd08ac564bee03885cce371';
