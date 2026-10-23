// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grant_member_essentials.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2865 — the one-tap member rights of the readiness card.

@ProviderFor(memberEssentialsGrant)
final memberEssentialsGrantProvider = MemberEssentialsGrantProvider._();

/// #2865 — the one-tap member rights of the readiness card.

final class MemberEssentialsGrantProvider
    extends
        $FunctionalProvider<
          MemberEssentialsGrant,
          MemberEssentialsGrant,
          MemberEssentialsGrant
        >
    with $Provider<MemberEssentialsGrant> {
  /// #2865 — the one-tap member rights of the readiness card.
  MemberEssentialsGrantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberEssentialsGrantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberEssentialsGrantHash();

  @$internal
  @override
  $ProviderElement<MemberEssentialsGrant> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemberEssentialsGrant create(Ref ref) {
    return memberEssentialsGrant(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemberEssentialsGrant value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemberEssentialsGrant>(value),
    );
  }
}

String _$memberEssentialsGrantHash() =>
    r'655cfe7e5c6a5771bf57d81e60ec71b1c18f0722';
