// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_display_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// member id → display name for the active workspace.

@ProviderFor(memberNames)
final memberNamesProvider = MemberNamesProvider._();

/// member id → display name for the active workspace.

final class MemberNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// member id → display name for the active workspace.
  MemberNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberNamesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return memberNames(ref);
  }
}

String _$memberNamesHash() => r'004c24caf27181af8978ae9eade5c76d7b3a50e3';

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).

@ProviderFor(memberProfiles)
final memberProfilesProvider = MemberProfilesProvider._();

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).

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
  /// button for shared numbers. #1833: each profile is the projection the
  /// caller may read in this space — the community fields for a space
  /// mate, the printed identity only with `viewPersonalData` or
  /// `issueInvoices` (invoices, letters, the Excel export).
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

String _$memberProfilesHash() => r'859101558ebf916f79f70b20bc9c65edbfe1ce3c';
